# Hope BackWeapon

Hope BackWeapon est une ressource FiveM qui permet d’afficher les armes directement dans le dos des joueurs lorsqu’elles ne sont pas équipées.

Le script fonctionne avec **ox_inventory** et **ox_lib**.

## Fonctionnalités

* Affichage des armes dans le dos
* Synchronisation entre les joueurs
* Sélection de l’arme à afficher
* Détection des armes présentes dans l’inventaire
* Position différente selon le type d’arme
* Possibilité de modifier la position de chaque arme
* Compatible avec ox_inventory
* Configuration simple

## Installation

Téléchargez la ressource puis placez-la dans votre dossier `resources`.

Ajoutez ensuite dans votre `server.cfg` :

```cfg
ensure ox_lib
ensure ox_inventory
ensure hope_backweapon
```

Pensez à démarrer `ox_lib` et `ox_inventory` avant la ressource.

## Utilisation

Pour ouvrir le menu :

```text
/hopebackweapon
```

Vous pouvez également utiliser :

```text
/armedos
```

Le menu permet de sélectionner l’arme que vous souhaitez afficher dans votre dos.

Lorsque l’arme est équipée, elle disparaît automatiquement du dos du joueur.

Lorsqu’elle est rangée, elle réapparaît.

## Configuration

La majorité des réglages se trouvent dans :

```text
shared/config.lua
```

Vous pouvez notamment modifier les commandes, les positions des armes et leurs rotations.

Il est également possible de définir une position spécifique pour certaines armes si le réglage par défaut ne convient pas.

## Dépendances

* ox_lib
* ox_inventory

## Export

Le menu peut être ouvert depuis une autre ressource avec :

```lua
exports['hope_backweapon']:openBackWeaponMenu()
```

## Support

Si vous rencontrez un problème avec la ressource, vous pouvez ouvrir une issue directement sur GitHub.

## Crédits

Développé par **Hope**.

https://github.com/Karmahghosting/hope_backweapon
