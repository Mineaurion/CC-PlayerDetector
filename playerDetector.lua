--- GLOBAL VARIABLES ---
local json -- json API
local config -- variable where the config will be loaded
local defaultConfig = { -- default config, feel free to change it
    ["version"] = 1.25,
    ["status"] = "SNAPSHOT",
    ["sides"] = {"back", "front", "left", "right", "bottom", "top"},
    ["emit_redstone_when_connected"] = true,
    ["api_uri"] = "https://api.mineaurion.com/v1/serveurs/"
}

--- INIT ---
-- Saves the config
local function saveConfig()
    local str = json.encodePretty(config)
    assert(str and str ~= "", "ERROR : Encoding of the config went wrong.")
    local file = fs.open("/config.json", "w")
    file.write(str)
    file.close()
end

-- Returns true if the program is up to date, false otherwise and nil on error
local function isUpToDate()
    local http_request = http.get("https://raw.githubusercontent.com/DaikiKaminari/playerDetector/master/version.json")
    if not http_request then
        print("WARNING : unable to check if the program is up to date. HTTP request failed.")
        return nil
    end
    local body_content = http_request.readAll()
    if body_content == "" or body_content == "[]" then
        print("WARNING : unable to check if the program is up to date. Request body is empty.")
        return nil
    end
    live_config = json.decode(body_content)
    live_version = live_config["version"]
    current_version = config["version"]
    return current_version >= live_version, live_config["should_old_config_be_erased"]
end

-- Update the program
local function update(should_old_config_be_erased, should_values_in_old_config_be_copied_to_new_config)
    local http_request = http.get("https://raw.githubusercontent.com/DaikiKaminari/playerDetector/master/playerDetector.lua")
    if not http_request then
        print("WARNING : failed to update. HTTP request failed.")
        return
    end
    local body_content = http_request.readAll()
    if body_content == "" then
        print("WARNING : failed to update. Request body is empty.")
        return
    end
    local program_file = fs.open("startup.lua", "w")
    program_file.write(body_content)
    program_file.close()
    if should_old_config_be_erased then
        shell.run("rm config.json")
    else
        config["version"] = defaultConfig["version"]
        saveConfig()
    end
    print("Reboot...")
    sleep(5)
    os.reboot()
end

-- Returns true if the server ip exists, false otherwise and nil if the API is not reachable
local function isServerIpValid(input)
    local http_request = http.get(defaultConfig["api_uri"] .. input)
    if not http_request then
        print("WARNING : failed to access the API. HTTP request failed.")
        return nil
    end
    local body_content = http_request.readAll()
    if body_content == "[]" or body_content == "[]" then
        return false
    end
    return true
end

local function init()
    -- load json API
    if not (fs.exists("json") or fs.exists("json.lua") or fs.exists("rom/modules/main/json.lua") or fs.exists("rom/modules/main/json.lua")) then
        print("INFO : json API not installed yet, downloading...")
        local http_request = http.get("https://raw.githubusercontent.com/DaikiKaminari/CC-Libs/master/ObjectJSON/json.lua")
        assert(http_request, "ERROR : failed to download the json API. HTTP request failed.")
        local f = fs.open("json.lua", "w")
        f.write(http_request.readAll())
        f.close()
        print("INFO : json API installed.")
    end
    json = require("json")

    -- Check if config file exists, otherwise create it
    if not fs.exists("config.json") then
        config = defaultConfig
        -- Reset display
        term.clear()
        term.setCursorPos(1, 1)
        
        -- Input
        config["pseudos"] = {}
        print("Ecris les pseudos a detecter (appuyer sur entrer pour l'ajout et aussi quand tu as termine) :")
        local input
        repeat
            input = io.read()
            if input ~= "" then
                table.insert(config["pseudos"], input)
            end
        until input==""

        print("Ecris l'IP du serveur sur lequel tu es (ex: infinity.mineaurion.com) :")
        local input
        repeat
            if input then -- enters the condition only if the player entered a wrong server IP
                print("L'IP renseignee n'existe pas ou l'API Mineaurion n'est pas accessible.")
                print("Retente :")
            end
            input = io.read()
        until isServerIpValid(input)
        config["server_ip"] = input

        -- Write config
        saveConfig()
    end

    -- Read config file
    config = json.decodeFromFile("/config.json")

    -- check update
    local is_up_to_date, should_old_config_be_erased = isUpToDate()
    if is_up_to_date then
        print("INFO : Up to date in version : " .. config["version"] .. "-" .. config["status"])
    elseif is_up_to_date == "nil" then
        print("INFO : Checking for updates failed.")
    else
        print("INFO : Updating...")
        update(should_old_config_be_erased) -- the computer should reboot if the update is successful
        print("INFO : Update failed.")
    end
end


--- UTILS ---
local function has_value(tab, val)
    for index,value in pairs(tab) do
      if value == val then
        return true
       end
     end
     return false
  end


--- FUNCTIONS ---
-- Returns true if the player is connected, false otherwise
local function arePlayersConnected(players, serverID)
    local http_request = http.get(config["api_uri"] .. config["server_ip"]).readAll()
    local body_content = json.decode(http_request)
    local joueurs = body_content["joueurs"]
    if not joueurs or not next(joueurs) then
        return false
    end
    for _,player in pairs(players) do
        if has_value(joueurs, player) then
            return true
        end
    end
    return false
end

-- Send or cut the redstone signal on all defined sides
local function actualizeRedstone(boolean_signal)
    if boolean_signal then
        for _,side in pairs(config["sides"]) do
            rs.setOutput(side, config["emit_redstone_when_connected"])
        end
    else
        for _,side in pairs(config["sides"]) do
            rs.setOutput(side, config["emit_redstone_when_connected"])
        end
    end
end


--- MAIN ---
local function main()
    init()
    print("\nDetecte les joueurs : " .. textutils.serialise(config["pseudos"]))
    print("Sur le serveur : " .. config["server_ip"])
    if config["emit_redstone_when_connected"] then
        print("\nEmet un signal de redstone quand un des joueur est connecte, sinon non.")
        print("Pour couper un spawner il faut donc inverser le signal, il est possible d'utiliser des transmitter/receiver de redstone.")
    else
        print("\nN'emet PAS signal redstone quand un des joueur est connecte, sinon oui.")
        print("Il suffit de coller le computer aux spawners, ou d'utiliser des transmitter/receiver de redstone.")
    end
    while true do
        actualizeRedstone(arePlayersConnected(config["pseudos"], config["server_ip"]))
        sleep(30)
    end
end

main()