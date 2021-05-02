local MSP_API_VERSION   = 1
local MSP_SET_RTC       = 246

local apiVersionReceived = false
local timeIsSet = false
local lastRunTS = 0
local INTERVAL = 50

local function processMspReply(cmd,rx_buf)
    if cmd == MSP_API_VERSION and #rx_buf >= 3 then
        apiVersion = rx_buf[2] + rx_buf[3] / 1000

        apiVersionReceived = true
    end
    if cmd == MSP_SET_RTC then
        timeIsSet = true
    end
end

local function init()
    if lastRunTS == 0 or lastRunTS + INTERVAL < getTime() then
        if not apiVersionReceived then
            protocol.mspRead(MSP_API_VERSION)
        elseif apiVersionReceived and not timeIsSet then
            -- only send datetime one time after telemetry connection became available
            -- or when connection is restored after e.g. lipo refresh
            local values = {}
            if apiVersion >= 1.041 then
                -- format: seconds after the epoch (32) / milliseconds (16)
                local now = getRtcTime()

                for i = 1, 4 do
                    values[i] = bit32.band(now, 0xFF)
                    now = bit32.rshift(now, 8)
                end

                values[5] = 0 -- we don't have milliseconds
                values[6] = 0
            else
                -- format: year (16) / month (8) / day (8) / hour (8) / min (8) / sec (8)
                local now = getDateTime()
                local year = now.year

                values[1] = bit32.band(year, 0xFF)
                year = bit32.rshift(year, 8)
                values[2] = bit32.band(year, 0xFF)
                values[3] = now.mon
                values[4] = now.day
                values[5] = now.hour
                values[6] = now.min
                values[7] = now.sec
            end

            protocol.mspWrite(MSP_SET_RTC, values)
        end
        lastRunTS = getTime()
    end

    mspProcessTxQ()

    processMspReply(mspPollReply())

    return apiVersionReceived and timeIsSet
end

return { f = init, t = "Waiting for API version" }
