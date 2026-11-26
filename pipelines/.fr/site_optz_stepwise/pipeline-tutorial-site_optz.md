_Auteurs: Francis van Oordt, Samara Manzin_

## Présentation

Les programmes de surveillance de la biodiversité devront peut-être élargir leur réseau d'échantillonnage ou revoir les sites qui ne sont plus régulièrement surveillés. Le choix de sites supplémentaires peut contribuer à améliorer la couverture des conditions environnementales et des zones géographiques peu représentées par le réseau actuel.

Ce pipeline utilise une procédure d'optimisation p-médiane pas à pas implémentée dans le paquet SURDES pour sélectionner des sites supplémentaires dans une liste de candidats fournie par l'utilisateur. La sélection tient compte des différences environnementales et des distances géodésiques entre les coordonnées du site en mètres, dans le but de compléter les sites déjà inclus dans le réseau de surveillance.

## Utilisations

Utilisez ce pipeline pour prioriser les points de demande lors de l'expansion ou de la rotation d'un réseau de surveillance. Les points de demande peuvent comprendre les sites d'échantillonnage historiques ou les nouveaux sites proposés.

La liste des entrées doit identifier deux groupes :

- **Sites actuels (`vini = 1`):** Sites déjà inclus dans le réseau de surveillance.
- **Points de demande (`vini = 0`):** Sites disponibles pour un échantillonnage supplémentaire.

Ensemble, ces groupes définissent l'ensemble des sites considérés dans l'analyse. Le pipeline extrait des valeurs environnementales à leur emplacement, calcule des matrices de distance et sélectionne des sites supplémentaires par étapes successives d'optimisation.

Les résultats comprennent des valeurs de sélection des sites, une carte et une courbe montrant les changements de variabilité non connus restants à mesure que les sites sont ajoutés. Ces sorties appuient les décisions concernant les points de demande à inclure et le nombre de sites supplémentaires à échantillonner.

## Limites du pipeline

- L'analyse représente la liste de sites fournie. Les conditions environnementales et les emplacements absents de cette liste ne sont pas directement représentés dans l'optimisation.
- Tous les sites ont besoin de données environnementales valides. Les emplacements situés en dehors de la couverture raster ou dans des cellules contenant des valeurs manquantes peuvent empêcher l'analyse de se terminer.
- Le temps de calcul augmente avec le nombre de sites et les itérations d'optimisation. Commencez par une petite course pour évaluer les performances.
- L'interface actuelle ne fournit pas de coûts définis par l'utilisateur, de contraintes d'accessibilité ou de conditions de sélection.
- La sortie de variabilité découverte est une mesure dérivée de la matrice de distance d'optimisation. Il ne doit pas être interprété comme un pourcentage de la biodiversité représentée.

## Avant de commencer

Préparer un CSV contenant une rangée par site et les colonnes suivantes:

- **lon:** Longitude en degrés décimaux, WGS84 (EPSG:4326).

- **lat:** Latitude en degrés décimaux, WGS84 (EPSG:4326).

- **vini:** L'indicateur initial de sélection du site utilisé par l'optimisation. Utiliser 1 pour les sites de surveillance actuels et 0 pour les points de demande disponibles pour un échantillonnage supplémentaire.

Utiliser des valeurs numériques sans coordonnées ou classifications manquantes. Inclure au moins un site actuel et un point de demande. Des colonnes supplémentaires peuvent contenir des identifiants de site ou d'autres attributs; elles ne saisissent pas les calculs de distance.

Les coordonnées d'entrée doivent toujours être WGS84 longitude et latitude, quel que soit le SCR sélectionné dans l'emplacement choisi. Les sites sont réaménagés à l'interne pour extraire des données environnementales; les distances géographiques sont calculées directement à partir des coordonnées WGS84.

Placez le fichier dans votre répertoire BON in a Box `userdata` et entrez son chemin de conteneur dans **Lieux d'échantillonnage**, par exemple `/userdata/sampling_sites.csv`.

Les variables environnementales, la résolution raster et les points de demande fournis déterminent les différences considérées par l'optimisation. Choisir des variables pertinentes aux objectifs de surveillance et s'assurer que leur couverture inclut tous les sites fournis. Définissez le nombre de sites supplémentaires à une valeur ne dépassant pas le nombre de lignes avec `vini = 0`.

## Exécution du pipeline

### Entrées du pipeline

- **Pays, région ou emprise :** Définir l'étendue de l'étude et choisir le système de coordonnées de référence utilisé pour récupérer les données environnementales.

- **Résolution spatiale :** Résolution raster environnementale dans les unités SCR sélectionnées: mètres pour un SCR mesuré en mètres, degrés pour EPSG:4326. S'il est vide, le chargeur tente la résolution native, nécessitant des unités SCR compatibles. Cela ne modifie pas les coordonnées d'entrée requises du WGS84 ni la méthode de distance géodésique.

- **items de collection STAC:** Fournir les variables environnementales en utilisant le format `collection|item`, comme `chelsa-clim|bio1` et `chelsa-clim|bio12`. Ces variables définissent les différences environnementales entre les sites.

- **Lieux d'échantillonnage:** Chemin vers un CSV avec lon et lat dans WGS84 décimum de degrés (EPSG:4326), et vini: 1 pour les sites actuels, 0 pour les points de demande. Les coordonnées d'entrée utilisent toujours WGS84, indépendamment du traitement sélectionné SCR.

- **Itérations d'algorithme:** Nombre entier de points de demande à ajouter. Ne doit pas dépasser le nombre de lignes avec vini = 0. Par exemple, 40 sites actuels et 60 points de demande permettent au plus 60 ajouts. Plus d'itérations prennent plus de temps.

### Étapes du pipeline

#### 1. **Rechercher des données environnementales** 
Charger le polygone de la zone d'étude et le rasters environnemental sélectionné.
#### 2. **Calculer les distances du site** 
Normaliser le rasters environnemental et calculer les distances euclidiennes entre les valeurs extraites sur les sites. Calculez séparément les distances géodésiques ellipsoïdales en mètres des coordonnées WGS84. Multipliez les entrées correspondantes pour créer la matrice de distance conjointe. La classification du site (vini) est utilisée par l'optimiseur, et non dans le calcul des distances.

Avec cette multiplication, une distance zéro dans les deux composants donne une distance de joint zéro. Changer le raster SCR ou la résolution peut affecter les valeurs environnementales; il ne modifie pas la méthode de distance géographique.
#### 3. **Choisir des sites supplémentaires** 
Échellez la matrice de distance par sa valeur maximale afin que toutes les entrées se situent entre 0 et 1, en préservant leurs différences relatives. Cela permet de prendre en compte le plafond de distance utilisé en interne par SURDES. Exécutez l'optimisation par étapes en utilisant les classifications du site actuel et le nombre d'itérations demandé. Si tous les points de demande sont demandés, le seul point restant est ajouté directement à la dernière étape afin d'éviter une limitation à un seul candidat dans SURDES.
#### 4. **Inspecter les résultats** 
Examiner les valeurs de sélection, la carte et le reste de la courbe de variabilité découverte.

### Sorties du pipeline

- **Sélection des points de demande :** CSV des points de demande nouvellement sélectionnés dans l'ordre de sélection, y compris lon, lat, vini, site row (ligne CSV originale, à partir de 1), sélectionné, sélection commande et statut. Les sites actuels sont exclus.

- **Variabilité non couverte :** CSV avec itération et découvert variabilité, calculée comme la somme des scores SURDES p-médian à chaque itération. Ce diagnostic n'est pas un pourcentage de biodiversité représenté et il n'est pas garanti de diminuer monotoniquement.

- **Variabilité non couverte graphique:** PNG montrant la somme des scores SURDES p-médian à chaque itération. Inspecter les sites sélectionnés; ce diagnostic n'est pas un pourcentage de biodiversité représenté.

- **Carte des points sélectionnés :** PNG montrant les sites actuels, les points de demande non sélectionnés et les points de demande sélectionnés dans différentes couleurs.

- **Sites d'échantillonnage GeoPackage:** GeoPackage contenant tous les sites d'entrée dans WGS84 avec vini, site row, selected, selection order, and status (current, Demand, or Selected). Utiliser le statut pour le style visualiseur ; les couleurs automatiques dépendent du visualiseur.

## Références

- Medina, N. G., Lara, F., Mazimpaka, V., & Hortal, J. (2013). Designing bryophyte surveys for an optimal coverage of diversity gradients. *Biodiversity and Conservation*, 22(13–14), 3121–3139. [Read the paper](https://doi.org/10.1007/s10531-013-0574-5)

