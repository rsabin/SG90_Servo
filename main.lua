ang = 90

print("Setando pwm")
pinSrv = 2
pwm.setup(pinSrv, 50, 71)

print("Criando timers")
tmrgo = tmr.create()
tmrstop = tmr.create()

tmrgo:register(3000, tmr.ALARM_SEMI, function() rodarServo(ang) end)
tmrstop:register(1000, tmr.ALARM_SEMI, function() pararServo() end)

print("Iniciando timergo")
tmrgo:start()


function rodarServo(angulo)
    print("Executando com angulo " .. angulo)
    if angulo == 90 then
        pwm.setduty(pinSrv, 27)
        ang = 0
    elseif angulo == 0 then
        pwm.setduty(pinSrv, 71)
        ang = -90
    elseif angulo == -90 then
        pwm.setduty(pinSrv, 123)
        ang = 90
    end

    print("\tGirando...")
    pwm.start(pinSrv)
    tmrstop:interval(1000)
    tmrstop:start()
    
end

function pararServo()
    print("\tParando!")
    pwm.stop(pinSrv)
    tmrgo:start()
end