print("INIT: Iniciando programa em 3 segundos.")

tmr.create():alarm(3000, tmr.ALARM_SINGLE, function() dofile("main.lua") end)
