_MAX_TENTATIVAS_IP = 5

_pinSrvSetupClock = nil
_pinSrvSetupDuty = nil
_pinSrvCurDuty = nil
_pinSrvCurTimer = nil
_pinSrv = 2
_timerDuty = tmr.create()
_timerDuty:register(1, tmr.ALARM_SEMI, function() stopTimerDuty() end)
_timerDutyRunning = false

_server2 = nil

_funcao2 = 1
_tenta2 = 1
_timer2 = tmr.create()
_timer2:alarm(1000, tmr.ALARM_SEMI, function() start_webserver() end)

_hostname = "ESP" .. node.chipid()
print("MAIN: Definindo nome do dispositivo na rede como " .. _hostname .. ".")
wifi.sta.sethostname(_hostname)

function start_webserver()

    if (_funcao2 == 1) then
        print("MAIN: Detectando IP e intensidade do sinal. Aguarde.")
        local _ip = wifi.sta.getip()
        local _rssi = wifi.sta.getrssi()

        if (_ip ~= nil) then
            print("MAIN: Conectado no wifi com o ip " .. _ip .. " e intensidade do sinal " .. _rssi .. ".")
            _tenta2 = 1
            _funcao2 = _funcao2 + 1

        else
            print("MAIN: Falhou na " .. _tenta2 .. "a tentativa. Aguarde 1 segundo.")
            _tenta2 = _tenta2 + 1
            if (_tenta2 >= _MAX_TENTATIVAS_IP) then
                print("MAIN: Falhou demais, mas vamos continuar assim mesmo.")
                _tenta2 = 1
                _funcao2 = _funcao2 + 1

            end
        end
        _timer2:start()

    
    elseif (_funcao2 == 2) then
        print("MAIN: Webserver inicializado. É só usar agora.")

        if (_server2 == nil) then
            _server2 = net.createServer(net.TCP, 60)
        end

        _server2:listen(80, listen2)

        _timer2:unregister()
    end

end

function get_http_req(instr)
    local t1 = {}
    local t2 = {}
    local first = nil
    local key, v, strt_ndx, end_ndx
    local body = 0

    for str in string.gmatch(instr, "([^\n]+)") do
        -- First line in the method and path
        if (first == nil) then
            first = 1
            strt_ndx, end_ndx = string.find(str, "([^ ]+)")
            v = trim(string.sub(str, end_ndx + 2))
            key = trim(string.sub(str, strt_ndx, end_ndx))
            t1["METHOD"] = key
            t1["REQUEST"] = v
        elseif (body == 0) then 
            strt_ndx, end_ndx = string.find(str, "([^:]+)")
            if (end_ndx ~= nil) then
                v = trim(string.sub(str, end_ndx + 2))
                key = trim(string.sub(str, strt_ndx, end_ndx))
                if ((key ~= "") or (v ~= "")) then
                    t1[key] = v
                else
                    body = 1
                end
            end
        elseif (body == 1) then
            for str2 in string.gmatch(str, "([^&]+)") do
                strt_ndx, end_ndx = string.find(str2, "([^=]+)")
                if (end_ndx ~= nil) then
                    v = trim(string.sub(str2, end_ndx + 2))
                    key = trim(string.sub(str2, strt_ndx, end_ndx))
                    if ((key ~= "") or (v ~= "")) then
                        t2[key] = v
                    end
                end
            end
        end
    end
    return t1, t2
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function listen2(sck)
    sck:on("receive", receive2)
    --sck:on("connection", connection2)
end

function connection2(sck, req)
    local _port, _ip = sck:getpeer()
    if (_ip ~= nil) then
        print("MAIN: Cliente " .. _ip .. " conectado (+) no webserver pela porta " .. _port .. ".")
    end
end

function receive2(sck, req)
    local _port, _ip = sck:getpeer()
    local _GET = {}
    if (_ip ~= nil) then
        print("MAIN: Cliente " .. _ip .. " enviando dados para o webserver.")
    end
    vars1, vars2 = get_http_req(req)
    for k, v in string.gmatch(vars1['REQUEST'], "(%w+)=(%w+)&*") do
        _GET[string.upper(k)] = v
    end
    --for k1, v1 in pairs(_GET) do
    --    print("\t" .. k1 .. " = \'" .. v1 .. "\'")
    --end

    if (_GET["SUBMIT"] ~= nil) then
        if (_GET["SUBMIT"] == "SETUP") then
            if ((_pinSrvSetupClock == nil) or (_pinSrvSetupDuty == nil)) then
                local _getCLOCKS, _getDUTYS = _GET["SETCLOCK"], _GET["SETDUTY"] 
                local _getCLOCKN, _getDUTYN = nil, nil
                
                if ((_getCLOCKS ~= nil) and (_getDUTYS ~= nil)) then
                    local _status1, _getCLOCKN = pcall(tonumber, _getCLOCKS) 
                    local _status2, _getDUTYN = pcall(tonumber, _getDUTYS)
                    if (_status1 and _status2) then
                        _pinSrvSetupClock = _getCLOCKN
                        _pinSrvSetupDuty = _getDUTYN
                        _pinSrvCurDuty = _getDUTYN
                        print("\tPWM.SETUP(" .. _pinSrvSetupClock .. ", " .. _pinSrvSetupDuty .. ")")
                        pwm.setup(_pinSrv, _pinSrvSetupClock, _pinSrvSetupDuty)
                    end 
                end
            end
        elseif (_GET["SUBMIT"] == "GIRA") then
            local _getDUTYS, _getTIMERS = _GET["DUTY"], _GET["TIMER"]
            local _getDUTYN, _getTIMERN = nil, nil
            if ((_getDUTYS ~= nil) and (_getTIMERS ~= nil)) then
                local _status1, _getDUTYN = pcall(tonumber, _getDUTYS)
                local _status2, _getTIMERN = pcall(tonumber, _getTIMERS) 
                if (_status1 and _status2) then
                    _pinSrvCurDuty = _getDUTYN
                    _pinSrvCurTimer = _getTIMERN
                    startTimerDuty(_pinSrvCurDuty, _pinSrvCurTimer)
                end 
            end
        end
    end
        
    
    local ht = {}
    table.insert(ht, "<!DOCTYPE html>\n<html>\n<head>\n<title>" .. _hostname .. "</title>\n<meta charset=\"UTF-8\" />\n</head>")
    table.insert(ht, "<body>\n<h1>SG90 Servo Motor</h1>")
    table.insert(ht, "<form id=\"frmSG90\" name=\"frmSG90\" method=\"get\" action=\"\">")
    if ((_pinSrvSetupClock == nil) or (_pinSrvSetupDuty == nil)) then
        table.insert(ht, "<p>Clock: <input type=\"number\" id=\"SETCLOCK\" name=\"SETCLOCK\" min=\"1\" max=\"1000\" value=\"50\" /></p>")
        table.insert(ht, "<p>Duty: <input type=\"number\" id=\"SETDUTY\" name=\"SETDUTY\" min=\"0\" max=\"1023\" value=\"71\" /></p>")
        table.insert(ht, "<p><input type=\"submit\" id=\"SUBMIT\" name=\"SUBMIT\" value=\"SETUP\" /></p>")
    else
        table.insert(ht, "<p>Clock: <input type=\"number\" id=\"SETCLOCK\" name=\"SETCLOCK\" value=\"" .. _pinSrvSetupClock .. "\" disabled /></p>")
        table.insert(ht, "<p>Duty: <input type=\"number\" id=\"SETDUTY\" name=\"SETDUTY\" value=\"" .. _pinSrvSetupDuty .. "\" disabled /></p>")
    end
    if ((_pinSrvSetupClock ~= nil) and (_pinSrvSetupDuty ~= nil)) then
        local DutyShow, TimerShow = 71, 1000
        if (_pinSrvCurDuty ~= nil) then
            DutyShow = _pinSrvCurDuty
        end
        if (_pinSrvCurTimer ~= nil) then
            TimerShow = _pinSrvCurTimer
        end
        table.insert(ht, "<p>Duty: <input type=\"number\" id=\"DUTY\" name=\"DUTY\" min=\"0\" max=\"1023\" value=\"" .. DutyShow .. "\" /></p>")
        table.insert(ht, "<p>Timer: <input type=\"number\" id=\"TIMER\" name=\"TIMER\" min=\"1\" max=\"10000\" value=\"" .. TimerShow .. "\" /></p>")
        table.insert(ht, "<p><input type=\"submit\" id=\"SUBMIT\" name=\"SUBMIT\" value=\"GIRA\" /></p>")
    end
    
    table.insert(ht, "</form>\n</body>\n</html>")

    local sht = 0
    for key, value in pairs(ht) do
        sht = sht + string.len(value) + 1
    end

    table.insert(ht, 1, "HTTP/1.1 200 OK")
    table.insert(ht, 2, "Server: " .. _hostname)
    table.insert(ht, 3, "Connection: keep-alive")
    table.insert(ht, 4, "Content-Type: text/html; charset=UTF-8")
    table.insert(ht, 5, "Cache-Control: no-cache")
    table.insert(ht, 6, "Content-Language: pt-BR, en-US")
    table.insert(ht, 7, "Content-Length: " .. sht .. "\n")

    local function sender(sck)
        if (#ht > 0) then
            sck:send(table.remove(ht, 1) .. "\n")
        else
            sck:close()
        end
    end

    if (_ip ~= nil) then
        print("MAIN: Webserver respondendo para o cliente " .. _ip .. ".")
    end
    sck:on("sent", sender)
    sender(sck)
end

function startTimerDuty(dutyValue, timerValue)
    if (_timerDutyRunning) then
        stopTimerDuty() 
    end
    _timerDuty:interval(timerValue)
    print("\tPWM.SETDUTY(" .. _pinSrvCurDuty .. ")\n\tTMR.INTERVAL(" .. _pinSrvCurTimer .. ")")
    pwm.setduty(_pinSrv, dutyValue)
    _timerDutyRunning = true
    _timerDuty:start()
end

function stopTimerDuty()
    _timerDutyRunning = false
    _timerDuty:stop()
    print("\tPWM.STOP()")
    pwm.stop(_pinSrv)
end

--[[
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

--]]
