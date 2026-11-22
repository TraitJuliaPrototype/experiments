#= base/task.jl =#
function yieldto(t::Task, @nospecialize(x=nothing))
    ct = current_task()
    # TODO: these are legacy behaviors; these should perhaps be a scheduler
    # state error instead.
    if t._state === task_state_done
        return x
    elseif t._state === task_state_failed
        throw(t.result)
    end
    # [task] user_time -yield-> wait_time
    record_running_time!(ct)
    # [task] created -scheduled-unfairly-> wait_time
    maybe_record_enqueued!(t)
    setfield!(t, :result, x)
    set_next_task(t)
    return try_yieldto(identity)
end

