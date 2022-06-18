# Player detector Mineaurion pour Computercraft

## Description
Le script `playerDector.lua`, une fois installé sur un PC computercraft, permet d'emmetre un signal de redstone si un des joueur renseigné est connecté sur un serveur spécifique.

## Fonctionnement
### Récupération du script en jeu
Récupérez le code du script `playerDetector.lua` en jeu, soit :
- en l'uploadant sur (pastebin)[https://pastebin.com/] pour avoir la dernière version puis en tapant en jeu `pastebin get <l'ID de ton paste> startup`
- en utilisant la (version déjà présente sur pastebin)[https://pastebin.com/UTzpeRmP] puis en tapant en jeu `pastebin get UTzpeRmP startup`
- en créant et exécutant ce petit script en jeu :

```lua
local request = http.get("https://raw.githubusercontent.com/Mineaurion/CC-PlayerDetector/master/playerDetector.lua")
local content = request.readAll()
local file = fs.open("startup", "r")
file.write(content)
file.close()
```

### Exécution du script
Faites un reboot du PC (en tapant `reboot`) ou en lançant directement le programme en tapant `startup`.
