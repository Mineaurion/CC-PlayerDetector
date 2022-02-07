--- GLOBAL VARIABLES ---
local json -- json API
local config -- variable where the config will be loaded
local defaultConfig = { -- default client config, feel free to change it
    ["version"] = 1.37,
    ["status"] = "SNAPSHOT",
    ["sides"] = {
        ["back"] = true,
        ["front"] = true,
        ["left"] = true,
        ["right"] = true,
        ["bottom"] = true,
        ["top"] = true
    },
    ["emit_redstone_when_connected"] = true,
    ["api_uri"] = "https://api.mineaurion.com/v1/serveurs/",
}

--- UTILS ---
-- Returns true if the tab contains the val
local function hasValue(tab, val)
    for index,value in pairs(tab) do
      if value == val then
        return true
      end
    end
    return false
end

-- Converts something in a boolean
local function toBoolean(anything)
    local false_equivalent = {nil, "nil", 0, 0.0, "0", "0.0", false, "false", "False", "FALSE"}
    for _,v in pairs(false_equivalent) do
        if anything == v then
            return false
        end
    end
    return true
end

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
    return current_version >= live_version, live_config["should_old_config_be_erased"], live_config["status"]
end

-- Update the program
local function update(should_old_config_be_erased, should_values_in_old_config_be_copied_to_new_config, status)
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
	local file_name = (status == "RELEASE") and "startup" or "player_detector_dev"
    local file = fs.open(file_name, "w")
    file.write(body_content)
    file.close()
    if should_old_config_be_erased then
        shell.run("rm config.json")
    else
        config["version"] = defaultConfig["version"]
        saveConfig()
    end
    print("INFO : update successful.\nINFO : reboot...")
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

-- Ask the player to write the pseudos to detect and update the config
local function setPseudosList(save_config)
    config["pseudos"] = {}
    print("\nEcris les pseudos a detecter (appuyer sur entrer pour l'ajout et aussi quand tu as termine) :")
    local input
    repeat
        input = io.read()
        if input ~= "" then
            table.insert(config["pseudos"], input)
        end
    until input==""
    if save_config then
        saveConfig()
    end
end

-- Ask the player to write the IP of the server he is on and update the config
local function setServer(save_config)
    print("\nEcris l'IP du serveur sur lequel tu es (ex: infinity.mineaurion.com) :")
    local input
    repeat
        if input then -- enters the condition only if the player entered a wrong server IP
            print("\nL'IP renseignee n'existe pas ou l'API Mineaurion n'est pas accessible.")
            print("Retente :")
        end
        input = io.read()
    until isServerIpValid(input)
    config["server_ip"] = input
    if save_config then
        saveConfig()
    end
end

-- Ask the player to configure sides where the redstone will be output
local function setSides(save_config)
    print("\nEcris 0 ou 1 selon si tu veux que le signal de redstone soit emit ou pas :")
    for side,status in pairs(config["sides"]) do
        print(side .. " : " .. tostring(status) .. " (statut courant)")
        local new_status = toBoolean(io.read())
        config["sides"][side] = new_status
        rs.setOutput(side, false)
    end
    if save_config then
        saveConfig()
    end
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
        setPseudosList(false)
        setServer(false)

        -- Write config
        saveConfig()
        print("INFO : config saved.\n")
    end

    -- Read config file
    config = json.decodeFromFile("/config.json")

    -- rename the computer in order to preserve the program if the computer is removed and replaced
    local pseudos_str = ""
    for _,pseudo in pairs(config["pseudos"]) do
        pseudos_str = pseudos_str .. "_" .. pseudo
    end
    shell.run("label set player_detector_de" .. pseudos_str)

    -- check update
    local is_up_to_date, should_old_config_be_erased, status = isUpToDate()
    if is_up_to_date then
        print("INFO : Up to date in version : " .. config["version"] .. "-" .. config["status"])
    elseif is_up_to_date == "nil" then
        print("INFO : Checking for updates failed.")
    else
        print("INFO : Updating...")
        update(should_old_config_be_erased, status) -- the computer should reboot if the update is successful
        print("INFO : Update failed.")
    end
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
        if hasValue(joueurs, player) then
            return true
        end
    end
    return false
end

-- Send or cut the redstone signal on all defined sides
local function actualizeRedstone(boolean_signal)
    if boolean_signal then
        for side,status in pairs(config["sides"]) do
            if status then
                rs.setOutput(side, config["emit_redstone_when_connected"])
            end
        end
    else
        for side,status in pairs(config["sides"]) do
            if status then
                rs.setOutput(side, config["emit_redstone_when_connected"])
            end
        end
    end
end

-- Change the config
local function doAction(key)
    if string.upper(key) == "RESET_PSEUDOS" then
        setPseudosList(true)
    elseif string.upper(key) == "RESET_SERVER_IP" then
        setServer(true)
    elseif string.upper(key) == "CONFIG_SIDES" then
        setSides(true)
    elseif string.upper(key) == "REBOOT" then
        os.reboot()
    else
        print("\nCommande non reconnue, liste des commandes reconnues : RESET_PSEUDOS, RESET_SERVER_IP, CONFIG_SIDES, REBOOT")
        return
    end
    os.reboot()
end

--- MAIN ---
local function runDetector()
    while true do
        actualizeRedstone(arePlayersConnected(config["pseudos"], config["server_ip"]))
        sleep(30)
    end
end

local function runDetectAction()
    while true do
        print("\nPour reset la config taper au choix ou reboot, ecris : RESET_PSEUDOS, RESET_SERVER_IP, CONFIG_SIDES, REBOOT")
        local input = io.read()
        doAction(input)
        sleep(0)
    end
end

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
    parallel.waitForAny(runDetector, runDetectAction)
end

main()