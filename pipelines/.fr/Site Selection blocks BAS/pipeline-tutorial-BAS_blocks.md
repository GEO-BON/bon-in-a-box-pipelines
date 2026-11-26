_Auteur(s): Francis van Oordt, Samara Manzin_

## Présentation

  La surveillance de la biodiversité exige des plans d'échantillonnage qui utilisent efficacement le temps limité, les budgets et l'accès sur le terrain. L'échantillonnage par acceptation équilibrée (SAB) sélectionne les sites d'échantillonnage répartis sur un zone d'étude au moyen d'une conception aléatoire spatialement équilibrée. Souvent, les chercheurs s'efforcent de prioriser l'échantillonnage en fonction de différents paramètres, l'un étant les caractéristiques environnementales de leur région d'étude (par exemple les biomes ou les régions écologiques). Des outils qui permettent des cadres d'échantillonnage rapides et robustes fournissent aux chercheurs des plans d'échantillonnage solides pour répondre à de multiples questions écologiques.

  Ce pipeline combine BAS et blocs environnementaux dérivés de variables environnementales choisies par les utilisateurs. Ces blocs regroupent des emplacements ayant des conditions environnementales similaires et aident les utilisateurs à évaluer dans quelle mesure les sites sélectionnés couvrent la variation environnementale des zone d'étude.

## Utilisations

  Utilisez ce pipeline pour planifier un nouveau réseau de surveillance et explorer comment les emplacements d'échantillonnage proposés couvrent différentes conditions environnementales.

- **Egalité d'échantillonnage:** Utilisez cette option lorsque vous voulez un échantillonnage de probabilité égale sur le zone d'étude. La carte des blocs environnementaux vous aide à inspecter les conditions environnementales représentées par les sites proposés.

- **Échantillonnage inégal** Utilisez cette option lorsque vous voulez la sélection du site pour donner plus de poids aux blocs environnementaux contenant plus de cellules raster. Cette option ne priorise pas spécifiquement les conditions environnementales rares ni ne donne à chaque bloc une représentation égale.

Examiner les emplacements proposés en même temps que les renseignements sur l'accès, la propriété foncière et les conditions sur le terrain avant les visites de planification. Le déplacement ou le remplacement de sites peut affecter les propriétés statistiques de la conception de l'échantillonnage.


## Limites du pipeline

  * Actuellement, le pipeline ne fonctionne que pour un contour géopolitique défini (p. ex. pays ou province).

  * Les blocs environnementaux reflètent la variation des variables environnementales choisies. Ils ne doivent pas être interprétés comme des biomes validés ou des régions écologiques.

  * Les blocs utilisent seulement les deux premiers composants principaux. Vérifiez le résumé ACP pour évaluer la variation environnementale que ces composantes expliquent.

  * Un échantillonnage inégal ne garantit pas une représentation égale des blocs environnementaux ou un échantillonnage préférentiel de conditions environnementales rares. Examiner les sites sélectionnés et leur couverture environnementale avant d'utiliser les résultats.

  * L'option inégale utilise un bassin fixe de 10 000 sites candidats. Si trop peu de candidats réussissent l'étape de filtrage, le nombre de sites valides requis peut ne pas être obtenu.

  * La sélection des sites ne tient pas compte de l'accessibilité sur le terrain, de la propriété foncière ou des contraintes logistiques.


## Avant de commencer
- Choisissez au moins deux variables environnementales continues pertinentes à vos objectifs de surveillance.

- Choisissez un nombre cible initial de sites d'échantillonnage en fonction de vos objectifs et ressources sur le terrain.

## Exécution du pipeline

### Entrées du pipeline

- **Emprise et SCR:** choisissez votre pays ou votre région d'intérêt, puis choisissez un système de coordonnées de référence (SCR) prévu approprié pour le zone d'étude en utilisant la liste déroulante.

- **Résolution spatiale :** Entier, résolution spatiale du rasters dans les mêmes unités que le système de coordonnées de référence (mètres pour les systèmes de référence projetés et degrés pour les systèmes de référence en lat long). Cette entrée peut être vide lors de l'utilisation de ESPG:4326.

- **Variables environnementales (items de collection STAC) :** Fournir au moins deux variables environnementales continues raster, en utilisant le format `collection|item`, comme `chelsa-clim|bio1` et `chelsa-clim|bio12`. Le pipeline effectue ACP sur ces variables pour créer les blocs environnementaux.

- **Type d'échantillonnage:** Sélectionner et option entre BAS égal ou probabilité inégale BAS. "Equal" ne tiendra pas compte des blocs et placera tous les échantillons au hasard dans l'ensemble du zone d'étude. "Unequal" tiendra compte de la taille de chaque bloc environnemental et redistribuera les sites d'échantillonnage en fonction de la taille du bloc.  

- **Objectif total des sites:** Un certain nombre de sites d'échantillonnage cibles à obtenir avec l'algorithme. L'utilisateur doit décider d'un certain nombre de sites en fonction de ses objectifs d'échantillonnage et de l'échelle de l'étude. 

Les zones d'étude plus vastes devraient avoir un plus grand nombre de lieux d'échantillonnage, mais il existe des contraintes (p. ex. budget, personnel, etc.) qui peuvent limiter les lieux d'échantillonnage et la couverture. 

Les chercheurs devraient tenir compte de leurs objectifs d'échantillonnage et de leur calendrier précis, et procéder avec prudence. 

- **Nombre de lignes et de colonnes:** Ces intrants divisent l'espace environnemental en une grille. Les lignes multipliées par des colonnes donnent le nombre maximum de blocs; certaines cellules de grille peuvent ne contenir aucune donnée environnementale. Pour une première opération exploratoire, 3 lignes et 3 colonnes donnent jusqu'à 9 blocs. Inspecter les résultats avant d'augmenter le détail de la grille. Le pipeline ne détermine pas le nombre de blocs à partir de la taille géographique du zone d'étude.


### Étapes du pipeline

#### 1. Récupérer des données environnementales 
Chargez le rasters environnemental sélectionné et le polygone de la zone d'étude.
#### 2. Créer des blocs environnementaux 
Agrégez et masquez le rasters, effectuez ACP et divisez les deux premiers composants principaux dans la grille demandée.
#### 3. Sélectionner des sites d'échantillonnage 
Appliquer le BAS égal ou la procédure d'échantillonnage inégal pondérée par blocs.
#### 4. Examen et résultats d'exportation
Inspectez les cartes et téléchargez les blocs environnementaux, le résumé ACP et les fichiers de sites sélectionnés.

### Sorties du pipeline

- **Les blocs environnementaux raster:** Un GeoTIFF catégorique identifiant le bloc environnemental attribué à chaque cellule raster classée.

- **Résumé de ACP:** Un CSV indiquant l'écart type, le pourcentage de variance expliqué et le pourcentage cumulatif de variance expliqué pour les composantes principales. Utilisez-le pour évaluer la variation environnementale que représentent les deux premières composantes.

- **Bloques et carte graphiques:** Figure montrant les blocs environnementaux dans l'espace principal à côté de leur répartition géographique.

- **Carte sortie:** Deux cartes montrant les sites d'échantillonnage proposés : une au-dessus du polygone de la zone d'étude et une au-dessus des blocs environnementaux. Utilisez-les pour inspecter la couverture géographique et environnementale.

- **Environnement rasters:** Le rasters environnemental récupéré pour l'analyse, a permis d'effectuer des inspections et des travaux d'exploration.

- **Points choisis :** CSV contenant les sites proposés : longitude et latitude dans WGS84 (EPSG:4326), avec colonnes nommées lon et lat.

- **Points sélectionnés GeoJSON:** Un fichier GeoJSON contenant les emplacements d'échantillonnage proposés dans WGS84 (EPSG:4326).

## Références
- [spbal: Spatially Balanced Sampling Algorithms](https://cran.r-project.org/web/packages/spbal/index.html)
- Survey-gap analysis in expeditionary research: where do we go from here?
  https://doi.org/10.1111/j.1095-8312.2005.00520.x
- Selection of sampling sites for biodiversity inventory: Effects of environmental and geographical considerations
  https://doi.org/10.1111/2041-210X.13869
