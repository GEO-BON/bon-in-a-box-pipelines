_Auteurs: Jory Griffith and Nina Obiar_

Statut de révision: En révision

## Présentation

Les indices aire protégée Représentativité et connectivité (PARC) mesurent la mesure dans laquelle aires protégées terrestre et d'autres mesures de conservation efficaces basées sur la zone (AMCE), sont représentatifs sur le plan écologique et bien reliés - tant entre eux qu'avec d'autres zones d'écosystèmes naturels intacts dans le paysage environnant (Hoskins et al., 2022).

L'indice de représentativité PARC fournit une mesure rigoureuse de la mesure dans laquelle un système terrestre de aires protégées et AMCE est écologiquement représentatif de l'ensemble de la diversité environnementale et biologique au sein d'une unité de déclaration spatiale donnée (p. ex. pays, temps général de l'écosystème). 

L'indice de connectivité PARC fournit une mesure rigoureuse de la mesure dans laquelle aires protégées et AMCE sont reliés fonctionnellement entre eux et à d'autres zones d'écosystèmes naturels intacts.

Ensemble, l'indicateur composite PARC permet de mesurer les progrès accomplis dans l'expansion de tout système de aires protégées et AMCE. L'indicateur est exprimé en proportion (ou en pourcentage) avec la position d'une unité de déclaration donnée sur cette échelle rigoureusement ajustée pour tenir compte des effets de la représentativité et de la connectivité.

Ce pipeline calcule une moyenne géométrique pondérée de l'indicateur PARC sur une région d'intérêt. Le code pour calculer la moyenne pondérée a été adapté à partir du script "Moyens géométrique pondérés de CSIRO BILBI" sur le [Portail d'accès aux données du CSIRO](https://doi.org/10.25919/edwj-4b67)

## Utilisations

Les indices PARC évaluent l'objectif A et la cible 3 du FBG, qu'ils soient générés séparément ou en tant que composites, afin de suivre et de signaler les tendances passées à aujourd'hui en matière de représentativité et de connectivité par des calculs répétés en utilisant la meilleure cartographie disponible de aires protégées et AMCE à plusieurs moments, par exemple pour différentes années. Ils peuvent également servir de base à l'évaluation de la contribution que les ajouts potentiels au système de aires protégées et de AMCE pourraient apporter à l'amélioration des scores actuels de PARC, ce qui permettrait de donner la priorité à ces actions.

### Limites du pipeline

- PARC est une couche modélisée, il y a donc de plus grandes incertitudes dans les zones où les données sont moins nombreuses. Interpréter les résultats avec prudence.

## Avant de commencer

Il n'y a pas de données ou de clés API nécessaires pour cette analyse.

## Exécution du pipeline

### Entrées du pipeline

BON in a Box contient un pipeline pour calculer les indicateurs PARC pour un domaine d'intérêt donné. Le pipeline comporte les entrées utilisateur suivantes:

- **Emprise et SCR :** l'utilisateur doit sélectionner un emprise et système de coordonnées de référence (SCR) à utiliser pour l'analyse. Cela peut être fait en utilisant le sélectionneur pour sélectionner un pays et/ou une région, ou entrer ou dessiner un emprise personnalisé. Ensuite, un SCR approprié peut être sélectionné dans le menu déroulant correspondant.

- **Date de début :** cette entrée est facultative. L'utilisateur peut sélectionner une date de début pour la série temporelle couches, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse sur toutes les années disponibles, l'utilisateur doit laisser cette entrée vide. Le couches commence à 2020-01-01.

- **Date de fin :** cette entrée est facultative. L'utilisateur peut sélectionner une date de fin pour la série temporelle couches, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse sur toutes les années disponibles, l'utilisateur doit laisser cette entrée vide. Le couches se termine à 2024-12-31.

- **Résolution temporaire :** cette entrée est facultative. L'utilisateur peut sélectionner une résolution temporelle pour la requête de items STAC par date, dans le format ("P", intervalle de temps, et unité de temps, par exemple "P1Y" est annuel, "P1M" est mensuel et "P1D" est quotidien). Si la résolution temporelle est plus grossière que la résolution temporelle des séries chronologiques, le couches sera agrégé avec la méthode d'agrégation choisie ci-dessous. L'utilisateur ne devrait pas mettre dans une résolution temporelle plus fine que celle du calque. L'ensemble de données PARC a une résolution temporelle de 5 ans entre 2000 et 2020, puis une couche pour 2024. L'utilisateur devrait laisser cette entrée vide si aucune date de début et de fin n'a été sélectionnée.

- **Résolution spatiale :** l'utilisateur peut sélectionner la résolution spatiale de la rasters. Cela doit être dans les mêmes unités que le système de coordonnées de référence (mètres pour les systèmes de référence projetés et degrés pour les systèmes de référence en longueur lat). Pour utiliser la résolution spatiale originale du couches, l'utilisateur doit laisser cette entrée vide. Si la résolution spatiale est laissé vide, la SCR sélectionnée doit être EPSG:4326.

- **Méthode de rééchantillonnage :** l'utilisateur doit choisir une méthode de rééchantillonnage à utiliser lorsque l'analyse nécessite un rééchelonnement vers une nouvelle résolution spatiale et/ou une nouvelle projection du raster couches. Voir [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) pour une description. Cette entrée sera ignorée s'il n'y a pas besoin de rééchantillonnage.

- **Méthode d'agrégation :** l'utilisateur doit sélectionner une méthode pour agréger les éléments lorsque couches est combiné dans le temps, par exemple si une résolution temporelle de cours est choisie. Cette entrée sera ignorée s'il n'y a pas besoin d'agrégation (la résolution temporelle du couches original est sélectionnée).

### Étapes du pipeline

#### **1. Obtenir le polygone de la zone d'intérêt**

Cette étape renvoie le polygone pour le pays, la région ou la zone d'intérêt. Si un pays/région a été sélectionné, il tire le polygone pays/région en utilisant le [API geoBoundaries](https://www.geoboundaries.org/), et sorties comme un GeoPackage, projeté dans le SCR d'intérêt. Si l'utilisateur entre un emprise personnalisé, il retournera un polygone fabriqué à partir de ce emprise.

#### **2. Chargement des données du catalogue GEO BON STAC**

Cette étape extrait d'abord le CSIRO aire protégée Representance and Connectedness (PARC) couches, puis le dénominateur CSIRO couches, des collections du GEO BON Spatio Temporal Asset Catalog. Les couches sont en résolution EPSG:4326 et 30 arc-seconde mais l'utilisateur peut spécifier d'autres résolutions systèmes de coordonnées de référence et spatiales. Le dénominateur CSIRO couches sert à calculer la moyenne géométrique pondérée du CSIRO PARC couches.

#### **3. Calcul de la moyenne arithmétique pondérée pour le BHI couches**

Cette étape calcule la moyenne arithmétique pondérée pour le PARC couches pour calculer le statistiques sommaires sur la zone d'intérêt.

### Sorties du pipeline

- **Raster couches de l'indicateur pour chaque année :** raster des fichiers PARC couches au format GeoTIFF.

- **PARC résumé:** moyenne géométrique pondérée annuelle de PARC dans le domaine d'intérêt. La valeur varie de 0 à 1, où une valeur plus élevée indique qu'un pourcentage plus élevé de la biodiversité et de la variation environnementale de la région est représenté en aires protégées. Une faible valeur suggère que certains types écologiques sont sous-représentés.

- **Heure série graphique:** graphique de la moyenne géométrique de PARC dans le temps dans la zone d'intérêt.

- **Pays:** pays d'intérêt, s'il est choisi.

- **Région:** région d'intérêt, s'il est sélectionné.

## Exemple

Exemple de sortie disponible bientôt.

## Dépannage

## Références
Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Ota, Noboru; Perry, Justin; & Williams, Kristen (2022): PARC: Protected Area Representativeness Index: 30s global time series. v2. CSIRO. Data Collection. https://doi.org/10.25919/edwj-4b67

Hoskins, Andrew J.; Harwood, Thomas D.; Ware, Chris; Williams, Kristen J.; Perry, Justin J.; Ota, Noburu; Croft, Jim R.; Yeates, David K.; Jetz, Walter; Golebiewski, Maciej; Purvis, Andy; Ferrier, Simon. (2020). BILBI: Supporting global biodiversity assessment through high-resolution macroecological modelling. Environmental Modelling & Software 132:104806. doi: https://doi.org/10.1016/j.envsoft.2020.104806 

