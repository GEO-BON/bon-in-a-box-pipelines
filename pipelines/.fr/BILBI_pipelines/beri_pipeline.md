_Auteurs: Jory Griffith, Nina Obiar_

Statut de révision: En révision

## Présentation

L'indice de résilience des écosystèmes bioclimatiques (BERI) du CSIRO est un indicateur reconnu au sein du Cadre mondial de la biodiversité de Kunming-Montréal (GBF) pour évaluer directement la cible 8, qui vise à minimiser les impacts du changement climatique sur la biodiversité et à renforcer la résilience. BERI mesure la capacité des écosystèmes naturels à conserver la biodiversité face aux changements climatiques (Ferrier et al., 2020). L'indicateur est fonction de la zone de l'écosystème, de la connectivité et de l'intégrité. BERI est un produit mondial de 30 arc-seconde pour les années 2000, 2005, 2010, 2015 et 2020 et est basé sur les données de plus de 400 000 espèces de plantes, de vertébrés et d'invertébrés (Harwood et al., 2022). 

BERI évalue dans quelle mesure la configuration de l'habitat naturel d'un paysage peut tenir compte des changements climatiques dans la répartition des espèces. Pour chaque maille de l'habitat naturel, l'indice évalue la connectivité fonctionnelle de la cellule aux zones avoisinantes qui devraient pouvoir soutenir un assemblage d'espèces semblables à celui qui est actuellement associé à cette cellule, face au changement climatique. Les cellules dont l'habitat est bien relié ont une note élevée, tandis que les régions isolées dont l'analogue climatique n'est pas acccessible ont une note faible. L'indicateur peut ensuite être agrégé et communiqué par n'importe quelle unité spatiale souhaitée – par exemple un type d'écosystème, un pays ou la planète entière.


Ce pipeline calcule une moyenne géométrique pondérée de l'indicateur BERI sur une région d'intérêt. Le code pour calculer la moyenne pondérée a été adapté à partir du script "Moyens géométrique pondérés de CSIRO BILBI" sur le [Portail d'accès aux données du CSIRO](https://doi.org/10.25919/4vvz-4j96)

### Utilisations
BERI peut être utilisé pour évaluer la cible 8 du FBG. Cet indicateur peut être utilisé pour surveiller et signaler les tendances passées à ce jour de la résilience de l'état des écosystèmes et de la connectivité face aux changements climatiques en cours. L'indice recalcule à plusieurs reprises l'indicateur en utilisant la meilleure cartographie disponible de l'état ou de l'intégrité de l'écosystème observée à plusieurs moments. 

Il peut également identifier les zones où la biodiversité peut être particulièrement vulnérable au changement climatique, quelles zones sont les mieux à protéger, et évaluer la manière dont les actions sectorielles proposées ou mises en œuvre sont censées conserver la diversité des espèces, fournissant ainsi une base plus solide pour la hiérarchisation stratégique de ces actions par les pays membres.

### Limites du pipeline

- BERI est une couche modélisée, il y a donc de plus grandes incertitudes dans les zones où les données sont moins nombreuses. Interpréter les résultats avec prudence.

## Avant de commencer

Il n'y a pas de données ou de clés API nécessaires pour cette analyse.

## Exécution du pipeline


### Entrées du pipeline

BON in a Box contient un pipeline pour calculer l'indicateur BERI pour une zone d'intérêt donnée. Le pipeline comporte les entrées utilisateur suivantes:

- **Emprise et SCR :** l'utilisateur doit sélectionner un emprise et système de coordonnées de référence (SCR) à utiliser pour l'analyse. Cela peut être fait en utilisant le sélectionneur pour sélectionner un pays et/ou une région, ou entrer ou dessiner un emprise personnalisé. Ensuite, un SCR approprié peut être sélectionné dans le menu déroulant correspondant.

- **Date de début :** cette entrée est facultative. L'utilisateur peut sélectionner une date de début pour la série temporelle couches, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse sur toutes les années disponibles, l'utilisateur doit laisser cette entrée vide. Le couches commence à 2020-01-01.

- **Date de fin :** cette entrée est facultative. L'utilisateur peut sélectionner une date de fin pour la série temporelle couches, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse sur toutes les années disponibles, l'utilisateur doit laisser cette entrée vide. Le couches se termine à 2024-12-31.

- **Résolution temporaire :** cette entrée est facultative. L'utilisateur peut sélectionner une résolution temporelle pour la requête de items STAC par date, dans le format ("P", intervalle de temps, et unité de temps, par exemple "P1Y" est annuel, "P1M" est mensuel et "P1D" est quotidien). Si la résolution temporelle est plus grossière que la résolution temporelle des séries chronologiques, le couches sera agrégé avec la méthode d'agrégation choisie ci-dessous. L'utilisateur ne devrait pas mettre dans une résolution temporelle plus fine que celle du calque. L'ensemble de données BERI a une résolution temporelle de 5 ans entre 2000 et 2020, puis une couche pour 2024. L'utilisateur devrait laisser cette entrée vide si aucune date de début et de fin n'a été sélectionnée.

- **Résolution spatiale :** l'utilisateur peut sélectionner la résolution spatiale de la rasters. Cela doit être dans les mêmes unités que le système de coordonnées de référence (mètres pour les systèmes de référence projetés et degrés pour les systèmes de référence en longueur lat). Pour utiliser la résolution spatiale originale du couches, l'utilisateur doit laisser cette entrée vide. Si la résolution spatiale est laissé vide, la SCR sélectionnée doit être EPSG:4326.

- **Méthode de rééchantillonnage :** l'utilisateur doit choisir une méthode de rééchantillonnage à utiliser lorsque l'analyse nécessite un rééchelonnement vers une nouvelle résolution spatiale et/ou une nouvelle projection du raster couches. Pour plus d'informations sur la méthode de rééchantillonnage (c.-à-d. proche, bilinéaire) à utiliser, veuillez consulter [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html). Cette entrée sera ignorée s'il n'y a pas besoin de rééchantillonnage.

- **Méthode d'agrégation :** l'utilisateur doit sélectionner une méthode pour agréger les éléments lorsque couches est combiné dans le temps, par exemple si une résolution temporelle de cours est choisie. Cette entrée sera ignorée s'il n'y a pas besoin d'agrégation (la résolution temporelle du couches original est sélectionnée).

### Étapes du pipeline

#### **1. Obtenir le polygone de la zone d'intérêt**

Cette étape renvoie le polygone pour le pays, la région ou la zone d'intérêt. Si un pays/région a été sélectionné, il tire le polygone pays/région en utilisant le [API geoBoundaries](https://www.geoboundaries.org/), et sorties comme un GeoPackage, projeté dans le SCR d'intérêt. Si l'utilisateur entre un emprise personnalisé, il retournera un polygone fabriqué à partir de ce emprise.

#### **2. Chargement des données du catalogue GEO BON STAC**

Cette étape extrait d'abord l'indice de résilience des écosystèmes bioclimatiques CSIRO (BERI) couches, puis le dénominateur CSIRO couches, des collections du GEO BON Spatio Temporal Asset Catalog. Les couches sont en résolution EPSG:4326 et 10x10 km, mais l'utilisateur peut spécifier d'autres systèmes de coordonnées et résolutions spatiales. Le dénominateur CSIRO couches sert à calculer la moyenne géométrique pondérée du CSIRO BERI couches.

#### **3. Calcul de la moyenne arithmétique pondérée pour le BERI couches**

Cette étape calcule la moyenne arithmétique pondérée pour le BERI couches pour calculer le statistiques sommaires sur la zone d'intérêt.

### Sorties du pipeline

- **Raster couches de l'indicateur pour chaque année :** raster des fichiers BERI couches au format GeoTIFF.

- **BERI résumé:** moyenne géométrique pondérée annuelle du BERI dans la zone d'intérêt. La valeur varie de 0 à 1 et représente la proportion de l'habitat relié qui devrait demeurer sous le changement climatique comparativement à ce qui existerait sans modification humaine ou changement climatique.

- **Heure série graphique:** graphique de la moyenne géométrique du BERI dans le temps dans la zone d'intérêt.

- **Pays:** pays d'intérêt, le cas échéant.

- **Région:** région d'intérêt, le cas échéant.

## Exemple

Exemple de sortie disponible bientôt.

## Dépannage

## Références
Ferrier, Simon; Harwood, Thomas D.; Ware, Chris; Hoskins, Andrew J (2020): A globally applicable indicator of the capacity of terrestrial ecosystems to retain biological diversity under climate change: The bioclimatic ecosystem resilience index. Ecological Indicators. doi: https://doi.org/10.1016/j.ecolind.2020.106554.

Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Hill, Samantha; Ota, Noboru; Perry, Justin; Purvis, Andy; & Williams, Kristen (2022): BERI v2: Bioclimatic Ecosystem Resilience Index: 30s global time series. v2. CSIRO. Data Collection. doi: https://doi.org/10.25919/4vvz-4j96