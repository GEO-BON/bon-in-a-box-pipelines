_Auteurs: Jory Griffith and Nina Obiar_

Statut de révision: En révision

## Présentation

Le CSIRO Indice d'habitat de la biodiversité (BHI) évalue directement les progrès accomplis dans la réalisation de l'objectif A au sein du Cadre mondial de la biodiversité de Kunming-Montréal (GBF) en vue d'accroître la superficie des écosystèmes nationaux d'ici 2050 en maintenant, en améliorant et en rétablissant l'intégrité, la connectivité et la résilience de tous les écosystèmes. 

BHI estime la proportion d'espèces qui devraient persister (c.-à-d. éviter l'extinction) à l'intérieur et à l'intérieur de l'unité de déclaration spatiale (Hoskins et al., 2020). Plus précisément, BHI estime le niveau de diversité des espèces que l'on s'attend à conserver au sein d'une unité de déclaration spatiale donnée (p. ex., un pays, un vaste type d'écosystème ou la planète entière) en fonction de la zone de l'unité, de la connectivité et de l'intégrité des écosystèmes naturels de l'ensemble de cette unité (Harwood et coll., 2022).

Les résultats de l'indicateur peuvent être exprimés comme suit : 1. la « proportion effective de l'habitat » restant à l'intérieur de l'unité – en fonction des effets de l'état et de la connectivité fonctionnelle de l'habitat, et de la variation spatiale de la composition des espèces des communautés écologiques (diversité beta); ou 2. la proportion efficace d'habitat qui peut se traduire, par l'analyse standard des espèces-zones, par un prédiction de la proportion d'espèces qui devrait persister (c.-à-d. éviter l'extinction) à long terme.

Ce pipeline calcule une moyenne géométrique pondérée de l'indicateur BERI sur une région d'intérêt. Le code pour calculer la moyenne pondérée a été adapté à partir du script "Moyens géométrique pondérés de CSIRO BILBI" sur le [Portail d'accès aux données du CSIRO](https://doi.org/10.25919/tt2t-h452)

## Utilisations

BHI traite directement de trois des principaux attributs écosystémiques de l'objectif A du FBG, qui comprennent la superficie, l'intégrité et la connétivité, ainsi que l'effet combiné de ces attributs sur la diversité des espèces.  

Le BHI sert à surveiller et à signaler les tendances passées à aujourd'hui de la persistance attendue de la diversité des espèces en recalculant à plusieurs reprises l'indicateur en utilisant la meilleure cartographie disponible de l'état ou de l'intégrité de l'écosystème observée à plusieurs moments, p. ex. pendant différentes années. Une grande variété de sources de données peut être utilisée à cette fin, couvrant des échelles spatiales allant de l'échelle mondiale à l'échelle infranationale, et comprenant des données rassemblées par les pays pour établir des comptes de l'état des écosystèmes dans le cadre du Système de comptabilité des écosystèmes de l'ONU.

Le BHI peut également servir d'indicateur de référence pour l'évaluation de la contribution que les actions sectorielles proposées ou mises en œuvre devraient apporter au renforcement de la capacité actuelle des écosystèmes à conserver la diversité des espèces, ce qui permettra aux pays membres de fixer des priorités stratégiques plus solides.

### Limites du pipeline

- BHI est une couche modélisée, il y a donc de plus grandes incertitudes dans les zones où les données sont moins nombreuses. Interpréter les résultats avec prudence.

## Avant de commencer

Il n'y a pas de données ou de clés API nécessaires pour cette analyse.

## Exécution du pipeline


### Entrées du pipeline

BON in a Box contient un pipeline pour calculer l'indicateur BHI pour une zone d'intérêt donnée. Le pipeline comporte les entrées utilisateur suivantes:

- **Emprise et SCR :** l'utilisateur doit sélectionner un emprise et système de coordonnées de référence (SCR) à utiliser pour l'analyse. Cela peut être fait en utilisant le sélectionneur pour sélectionner un pays et/ou une région, ou entrer ou dessiner un emprise personnalisé. Ensuite, un SCR approprié peut être sélectionné dans le menu déroulant correspondant.

- **Date de début :** cette entrée est facultative. L'utilisateur peut sélectionner une date de début pour la série temporelle couches, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse sur toutes les années disponibles, l'utilisateur doit laisser cette entrée vide. Le couches commence à 2020-01-01.

- **Date de fin :** cette entrée est facultative. L'utilisateur peut sélectionner une date de fin pour la série temporelle couches, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse sur toutes les années disponibles, l'utilisateur doit laisser cette entrée vide. Le couches se termine à 2024-12-31.

- **Résolution temporaire :** cette entrée est facultative. L'utilisateur peut sélectionner une résolution temporelle pour la requête de items STAC par date, dans le format ("P", intervalle de temps, et unité de temps, par exemple "P1Y" est annuel, "P1M" est mensuel et "P1D" est quotidien). Si la résolution temporelle est plus grossière que la résolution temporelle des séries chronologiques, le couches sera agrégé avec la méthode d'agrégation choisie ci-dessous. L'utilisateur ne devrait pas mettre dans une résolution temporelle plus fine que celle du calque. L'ensemble de données BHI a une résolution temporelle de 5 ans entre 2000 et 2020, puis une couche pour 2024. L'utilisateur devrait laisser cette entrée vide si aucune date de début et de fin n'a été sélectionnée.

- **Résolution spatiale :** l'utilisateur peut sélectionner la résolution spatiale de la rasters. Cela doit être dans les mêmes unités que le système de coordonnées de référence (mètres pour les systèmes de référence projetés et degrés pour les systèmes de référence en longueur lat). Pour utiliser la résolution spatiale originale du couches, l'utilisateur doit laisser cette entrée vide. Si la résolution spatiale est laissé vide, la SCR sélectionnée doit être EPSG:4326.

- **Méthode de rééchantillonnage :** l'utilisateur doit choisir une méthode de rééchantillonnage à utiliser lorsque l'analyse nécessite un rééchelonnement vers une nouvelle résolution spatiale et/ou une nouvelle projection du raster couches. Voir [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) pour une description. Cette entrée sera ignorée s'il n'y a pas besoin de rééchantillonnage.

- **Méthode d'agrégation :** l'utilisateur doit sélectionner une méthode pour agréger les éléments lorsque couches est combiné dans le temps, par exemple si une résolution temporelle de cours est choisie. Cette entrée sera ignorée s'il n'y a pas besoin d'agrégation (la résolution temporelle du couches original est sélectionnée).

### Étapes du pipeline

#### **1. Obtenir le polygone de la zone d'intérêt**

Cette étape renvoie le polygone pour le pays, la région ou la zone d'intérêt. Si un pays/région a été sélectionné, il tire le polygone pays/région en utilisant le [API geoBoundaries](https://www.geoboundaries.org/), et sorties comme un GeoPackage, projeté dans le SCR d'intérêt. Si l'utilisateur entre un emprise personnalisé, il retournera un polygone fabriqué à partir de ce emprise.

#### **2. Chargement des données du catalogue GEO BON STAC**

Cette étape extrait d'abord le CSIRO Indice d'habitat de la biodiversité (BHI) couches, puis le dénominateur CSIRO couches, des collections du GEO BON Spatio Temporal Asset Catalog. Les couches sont en résolution EPSG:4326 et 30 arc-seconde, mais l'utilisateur peut spécifier d'autres systèmes de référence de coordonnées et résolutions spatiales. Le dénominateur CSIRO couches sert à calculer la moyenne géométrique pondérée du CSIRO BHI couches.

#### **3. Calcul de la moyenne arithmétique pondérée pour le BHI couches**

Cette étape calcule la moyenne arithmétique pondérée pour le BHI couches pour calculer le statistiques sommaires sur la zone d'intérêt.

### Sorties du pipeline

- **Raster couches de l'indicateur pour chaque année :** raster des fichiers BHI couches au format GeoTIFF.

- **BHI résumé:** moyenne géométrique pondérée annuelle du BHI dans la zone d'intérêt. La valeur varie de 0 à 1, où une valeur plus élevée indique qu'une grande proportion de l'habitat demeure en bon état et est bien reliée, ce qui entraîne une forte attente de persistance de l'espèce. Une valeur inférieure indique qu'une proportion importante de l'habitat original a été perdue, dégradée ou fragmentée, ce qui met la biodiversité en danger.

- **Série horaire graphique:** graphique de la moyenne géométrique du BHI dans le temps dans la zone d'intérêt.

- **Pays:** pays d'intérêt, s'il est choisi.

- **Région:** région d'intérêt, s'il est sélectionné.

## Exemple
Exemple de sortie disponible bientôt.

## Dépannage

## Références
Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Hill, Samantha; Ota, Noboru; Perry, Justin; Purvis, Andy; & Williams, Kristen (2022): BHI v2: Biodiversity Habitat Index: 30s global time series. v1. CSIRO. Data Collection. doi: https://doi.org/10.25919/tt2t-h452

Hoskins, Andrew J.; Harwood, Thomas D.; Ware, Chris; Williams, Kristen J.; Perry, Justin J.; Ota, Noburu; Croft, Jim R.; Yeates, David K.; Jetz, Walter; Golebiewski, Maciej; Purvis, Andy; Ferrier, Simon. (2020). BILBI: Supporting global biodiversity assessment through high-resolution macroecological modelling. Environmental Modelling & Software 132:104806. doi: https://doi.org/10.1016/j.envsoft.2020.104806 