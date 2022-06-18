--- GLOBAL VARIABLES ---
local json -- json API
local config -- variable where the config will be loaded from the file config.json
local api_url = "http://api.mineaurion.com/"

-- github informations for auto update purpose
local organization_name = "Mineaurion"
local repo_name = "CC-PlayerDetector"
local branch = "master"
local dev_branch = "evolution-new-api"

--- COMPUTED VARIABLES ---
local args = {...}
local base_repo_content_url = "https://raw.githubusercontent.com/" .. organization_name .. "/" .. repo_name .. "/" .. branch .."/"
if args[1] == "dev" then
    base_repo_content_url = "https://raw.githubusercontent.com/" .. organization_name .. "/" .. repo_name .. "/" .. dev_branch .."/"
end

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

-- Creates local version.json file based on remote version.json file
local function createVersionFile()
    local url = base_repo_content_url .. "version.json"
    local http_request = http.get(url)
    assert(http_request, "ERROR : unable to reach github repo. HTTP request failed on" .. url)
    body_content = http_request.readAll()
    version_json = json.decode(body_content)
    version_json["should_old_config_be_erased"] = nil
    local file = assert(fs.open("version.json", "w"))
    file.write(json.encode(version_json))
    file.close()
end

-- Returns true if the program is up to date, false otherwise or if the remote version is not a release and nil on error
local function isUpToDate()
    local http_request = http.get(base_repo_content_url .. "version.json")
    if not http_request then
        print("WARNING : unable to check if the program is up to date. HTTP request failed.")
        return nil
    end
    local body_content = http_request.readAll()
    if body_content == "" or body_content == "[]" then
        print("WARNING : unable to check if the program is up to date. Request body is empty.")
        return nil
    end
    live_version = json.decode(body_content)
    version = json.decodeFromFile("version.json")
    current_version = version["version"]
    is_up_to_date = live_version["status"] == "RELEASE" and current_version >= live_version["version"]
    return is_up_to_date, live_version["should_old_config_be_erased"], live_version["status"], live_version["version"]
end

-- Update the program
local function update(should_old_config_be_erased, live_status, live_version)
    local http_request = http.get(base_repo_content_url .. "playerDetector.lua")
    if not http_request then
        print("WARNING : failed to update. HTTP request failed.")
        return
    end
    local body_content = http_request.readAll()
    if body_content == "" then
        print("WARNING : failed to update. Request body is empty.")
        return
    end
    -- if the status is a release then overwrite the code of statup.lua and erase player_detector_dev.lua, otherwise create file player_detector_dev.lua
	local file_name = (status == "RELEASE") and "startup" or "player_detector_dev"
    local file = fs.open(file_name, "w")
    file.write(body_content)
    file.close()
    if status == "RELEASE" then
        shell.run("rm player_detector_dev")
    end
    -- erase the local config if the new version has breaking changes
    if should_old_config_be_erased then
        shell.run("rm config.json")       
    end
    -- re-create version.json file
    createVersionFile()
    print("INFO : update from version" .. config["version"] .. "-" .. config["status"] .. "to version" .. live_version .. "-" .. live_status  .. "successful.\nINFO : reboot...")
    sleep(5)
    os.reboot()
end

-- Returns true if the server ip exists, false otherwise and nil if the API is not reachable
local function isServerIpValid(input)
    local http_request = http.get(api_url .. "query/" .. input)
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
        local input = io.read()
        local new_status = (input == "") or toBoolean(input)
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
        local url = base_repo_content_url .. "json.lua"
        local http_request = http.get(url)
        assert(http_request, "ERROR : failed to download the json API. HTTP request failed on" .. url)
        local f = fs.open("json.lua", "w")
        f.write(http_request.readAll())
        f.close()
        print("INFO : json API installed.")
    end
    json = require("json")

    -- check if version.json file exists, otherwise create it
    if not fs.exists("version.json") then
        createVersionFile()
    end

    -- check if config file exists, otherwise create it
    if not fs.exists("config.json") then
        local url = base_repo_content_url .. "default_config.json"
        local http_request = http.get(url)
        assert(http_request, "ERROR : unable to reach github repo. HTTP request failed on" .. url)
        config = json.decode(http_request.readAll())
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

    -- check updates
    local is_up_to_date, should_old_config_be_erased, live_status, live_status = isUpToDate()
    if is_up_to_date then
        print("INFO : Up to date in version : " .. config["version"] .. "-" .. config["status"])
    elseif is_up_to_date == "nil" then
        print("INFO : Checking for updates failed.")
    else
        print("INFO : Updating...")
        update(should_old_config_be_erased, live_status, live_status) -- the computer should reboot if the update is successful
        print("INFO : Update failed.")
    end

    -- Read config file
    config = json.decodeFromFile("/config.json")

    -- rename the computer in order to preserve the program if the computer is broke and replaced
    local pseudos_str = ""
    for _,pseudo in pairs(config["pseudos"]) do
        pseudos_str = pseudos_str .. "_" .. pseudo
    end
    shell.run("label set player_detector_de" .. pseudos_str)
end

--- FUNCTIONS ---
-- Returns true if the player is connected, false otherwise
local function arePlayersConnected(registered_pseudos, serverID)
    local http_request = http.get(api_url .. "query/" .. serverID)
    if not http_request then
        print("WARNING : unable to reach Mineaurion API. HTTP request failed.")
        return false
    end
    local body_content = http_request.readAll()
    if body_content == "" or body_content == "[]" or body_content == "{}" then
        print("WARNING : unable to reach Mineaurion API. Request body is empty.")
        return false
    end

    local body_content = json.decode(body_content)
    local connected_players = body_content["players"]
    if not connected_players or not next(connected_players) then
        return false
    end
    
    for _,pseudo in pairs(registered_pseudos) do
        if hasValue(connected_players, pseudo) then
            return true
        end
    end
    return false
end

--- OTHER FUNCTIONS ---
-- Send or cut the redstone signal on all defined sides
local function actualizeRedstone(player_connected)
    for side,status in pairs(config["sides"]) do
        if status then
            rs.setOutput(side, config["emit_redstone_when_connected"] == player_connected)
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
local function runPlayerDetector()
    while true do
        local is_someone_connected = arePlayersConnected(config["pseudos"], config["server_ip"])
        actualizeRedstone(is_someone_connected)
        sleep(60)
    end
end

local function runDetectCommand()
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
    parallel.waitForAny(runPlayerDetector, runDetectCommand)
end

main()