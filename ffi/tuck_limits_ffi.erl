%% SPDX-License-Identifier: Apache-2.0

%% Put a difficult template in its own room. A private reference separates its
%% reply from the caller's messages; cancellation joins the worker and drains
%% its reply before returning. No worker is left chewing on an abandoned render.
-module(tuck_limits_ffi).
-export([run/4]).

run(Work, Reductions, HeapWords, TimeoutMs) ->
    Parent = self(),
    Tag = make_ref(),
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    Worker = fun() ->
        Reply = try Work() of
            Result ->
                {reductions, Used} = process_info(self(), reductions),
                case Used > Reductions of
                    true -> {error, 1};
                    false -> {ok, Result}
                end
        catch
            _Class:_Reason -> {error, 4}
        end,
        Parent ! {Tag, Reply}
    end,
    Heap = #{size => HeapWords, kill => true, error_logger => false,
             include_shared_binaries => true},
    {Pid, Monitor} = spawn_opt(Worker, [monitor, {max_heap_size, Heap}]),
    watch(Pid, Monitor, Tag, Reductions, Deadline).

watch(Pid, Monitor, Tag, Reductions, Deadline) ->
    Remaining = Deadline - erlang:monotonic_time(millisecond),
    case Remaining =< 0 of
        true -> cancel(Pid, Monitor, Tag, 3);
        false ->
            receive
                {Tag, Reply} ->
                    erlang:demonitor(Monitor, [flush]),
                    Reply;
                {'DOWN', Monitor, process, Pid, killed} -> {error, 2};
                {'DOWN', Monitor, process, Pid, _Reason} -> {error, 4}
            after min(Remaining, 1) ->
                case process_info(Pid, reductions) of
                    {reductions, Used} when Used > Reductions ->
                        cancel(Pid, Monitor, Tag, 1);
                    _ -> watch(Pid, Monitor, Tag, Reductions, Deadline)
                end
            end
    end.

cancel(Pid, Monitor, Tag, Code) ->
    exit(Pid, kill),
    receive {'DOWN', Monitor, process, Pid, _} -> ok end,
    receive {Tag, _} -> ok after 0 -> ok end,
    {error, Code}.
