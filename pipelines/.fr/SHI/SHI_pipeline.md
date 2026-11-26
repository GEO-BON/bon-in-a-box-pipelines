# Indice d'habitat des espèces et Score d'habitat des espèces  

### Auteur(s): Maria Isabel Arce-Plata, Guillaume Larocque, Jaime Burbano-Girón, Maria Camila Díaz, Timothée Poisot, Jory Griffith, Jean-Michel Lord  

#### Révisé par: En révision

## Présentation
Le [Indice d'habitat des espèces](https://geobon.org/ebvs/indicators/species-habitat-index-shi/) (SHI) est un indicateur de composants pour le Cadre mondial de la biodiversité (GBF). SHI suit les changements dans l'intégrité écologique en mesurant les changements dans la qualité et la connectivité des habitats des espèces. Il s'agit d'un ensemble de valeurs de l'habitat des espèces (SHS), qui mesurent la superficie appropriée pour une seule espèce d'intérêt, par rapport à la taille totale de son aire de répartition.  

L'indice comporte deux composantes : 1) un score de surface et 2) un score de connectivité qui sont mesurés pour l'habitat de l'espèce requise (Score d'habitat des espèces). Le Indice d'habitat des espèces est la moyenne entre ces scores pour l'indice zone d'étude. Il peut aussi avoir des valeurs de poids attribuées en fonction de la proportion de la superficie de l'habitat de l'espèce située dans le zone d'étude.

Les pipelines BON in a Box calculent SHS et SHI. Le pipeline utilise cartes de répartition des espèces, le plages d'altitude et les catégories d'habitat disponibles de l'Union internationale pour la conservation de la nature (UICN). Pour le cas particulier du Québec, il a cartes de répartition disponible auprès du ministère de l'Environnement. Zone d'habitat convenable et de connectivité mesurée à l'aide du Global Forest Watch couches, et bientôt d'autres couverture du sol couches seront ajoutés. Plus d'informations sur la méthodologie du pipeline peuvent être lues [ici](https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf).

## Cas d'utilisation/Contexte
Le SHI est un indicateur important pour évaluer les progrès accomplis dans la réalisation de l'objectif A du FBG, qui appelle à une meilleure intégrité des écosystèmes naturels. En savoir plus sur la façon dont SHI peut être utilisé pour évaluer les progrès vers l'objectif A ici ([https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf](https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf)).

## Limites du pipeline
Actuellement, le pipeline utilise uniquement des données Global Forest Watch pour mesurer les changements dans l'habitat, de sorte que le pipeline se limite au calcul des SHS et SHI pour les espèces forestières.

## Avant de commencer
Pour utiliser ce pipeline, vous aurez besoin d'un [Jeton UICN](https://api.iucnredlist.org/users/sign_up) pour accéder aux données sur l'Union internationale pour la conservation de la nature (UICN) polygones des aires de répartition des espèces.

## Exécution du pipeline

### Entrées du pipeline
BON in a Box a un pipeline pour calculer SHS et SHI pour les espèces, les pays et les régions d'intérêt. Le pipeline comporte les entrées utilisateur suivantes:

- **Espèces:** Liste des noms scientifiques des espèces pour lesquelles vous voulez calculer l'indice SHI.

- **Zone d'étude option:** Que le zone d'étude d'intérêt soit un pays, une région ou un utilisateur fourni polygone.

- **Pays:** Pays intéressant à utiliser comme zone d'étude. Vérifiez les pays et régions disponibles [ici](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/).

- **Région:** Région d'intérêt à utiliser comme zone d'étude. Pour être utilisé lorsque vous voulez des limites administratives plus spécifiques. Vérifiez les pays et régions disponibles [ici](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/).

- **Zone d'étude:** Polygone du zone d'étude, au format GeoPackage. Saisissez le chemin vers le fichier dans les données utilisateur (par exemple /userdata/study area polygon.gpkg). Pour être utilisé lorsque l'entrée `Study area option` est sélectionnée pour être *utilisateur défini*.

- **Tampon pour zone d'étude:** Taille du tampon autour du zone d'étude. Pour éviter d'avoir des effets de bord dans les calculs, on utilise un tampon pour limiter la zone d'étude. Par défaut, la moitié de la largeur totale du zone d'étude.

- **Type de carte de répartition:** Utilisé pour sélectionner le type de carte de répartition. Ceci est basé sur le type de fichier source choisi ou fourni, où le fichier source peut être un polygone, raster, ou les deux.

- **Source de carte de répartition d'experts:** Source à partir de laquelle obtenir le carte de répartition d'experts pour les espèces d'intérêt. Les options sont : Map of Life (MOL), Union internationale pour la conservation de la nature (UICN) et cartes de répartition du ministère de l'Environnement du Québec (QC).

- **Carte de répartition (raster) :** raster avec la superficie prévue pour les espèces d'intérêt. À utiliser lorsque l'entrée `Type of range map` est sélectionnée pour être *raster*.

- **Système de référence spatiale:** Système de référence pour le domaine d'intérêt. Il peut s'agir 1) de l'identificateur du système de référence spatiale (RSID), 2) du nom de l'autorité (par exemple EPSG) avec le SRID ou 3) de la description des détails du système de référence spatiale (par exemple [https://spatialreference.org/]. Si seulement le SRID est donné et le logiciel ne peut pas trouver le système de référence essayer les options 2 ou 3.

- **Forêts minières:** Pourcentage minimum de couvert arboré requis pour chaque espèce, en fonction de son habitat convenable. agit comme un filtre pour les données Global Forest Watch. Si elle n'est pas disponible, utiliser les valeurs de Map of Life (p. ex. [https://mol.org/species/range/Myrmecophaga-tridactyla]). Pour plusieurs espèces, entrer dans le même ordre que l'entrée dans les espèces et séparer avec une virgule.

- **Forêt maximale:** Pourcentage maximal de couvert arboré requis pour chaque espèce, selon l'habitat convenable de l'espèce. agit comme un filtre pour les données Global Forest Watch. Si elle n'est pas disponible, utiliser les valeurs de Map of Life (p. ex. [https://mol.org/species/range/Myrmecophaga-tridactyla]). Pour plusieurs espèces, entrer dans le même ordre que l'entrée dans les espèces et séparer avec une virgule.

- **Année de début :** L'année à laquelle l'analyse devrait commencer doit être 2000 ou plus tard. Vérifiez l'intervalle de temps disponible pour les données Global Forecst Watch [ici](https://stac.geobon.org/collections/gfw-lossyear).

- **Année de fin:** L'année à laquelle l'analyse doit se terminer doit être postérieure à l'entrée `Initial time`. Il devrait être dans l'intervalle de temps pour les données Global Forest Watch (GFW) qui peuvent être trouvées [ici](https://stac.geobon.org/collections/gfw-lossyear).

- **Pas de temps:** Résolution temporelle pour analyse, en nombre d'années. Pour obtenir des valeurs pour le année de fin, le pas de temps devrait s'intégrer uniformément dans la plage d'analyse donnée.

- **Résolution spatiale des sorties:** L'utilisateur peut spécifier la résolution spatiale à laquelle il veut mesurer le changement d'habitat.

- **Filtre par altitude :** L'utilisateur peut décider s'il veut inclure altitude dans le carte de répartition des espèces d'intérêt. Si “yes” est choisi, le pipeline extrait les préférences de l'espèce altitude de l'UICN et enlève les zones situées à l'intérieur du carte de répartition qui sont en dehors de l'aire d'élévation de l'espèce. L'utilisateur peut également spécifier un tampon aux valeurs altitude.

- **Altitude tampon:** altitude tampon (en mètres) à ajouter ou à soustraire à l'aire de répartition altitude déclarée. La valeur par défaut est zéro. Les valeurs positives augmenteront l'intervalle de ce nombre en mètres, tandis que les valeurs négatives diminueront l'intervalle de ce nombre.

- **Méthode de rééchantillonnage :** Méthode de rééchantillonnage utilisée lors du rééchelonnement du raster couches. Voir [gdalwrap](https://gdal.org/en/latest/programs/gdalwarp.html) pour une description.

- **Méthode d'agrégation:** Méthode utilisée pour agréger les éléments qui se chevauchent. 

### Étapes du pipeline

#### **1. Obtenir la carte aire de répartition de l'espèce**
Cette étape télécharge le carte de répartition pour les espèces d'intérêt de la source experte choisie (ICUN, MOL ou QC).

#### **2. Obtenir la zone d'habitat**
Cette étape permet de calculer la superficie d'habitat des espèces d'intérêt.

#### **3. Mesure du changement de l'habitat**
Cette étape utilise la zone d'habitat de l'espèce avec GFW couches pour mesurer les changements dans l'habitat de l'espèce. Il utilise la couche forestière 2000 comme référence et enlève les pixels de la couche de perte des données GFW.

#### **4. Calcul de l'indice SHI**
Ces étapes calculent le Indice d'habitat des espèces (SHI) pour les espèces d'intérêt. Le SHI est la mesure du changement dans la zone et de la connectivité des zones appropriées par rapport à une base de référence. Il s'agit d'un ensemble de valeurs de l'habitat des espèces (SHS), qui mesurent le changement dans la zone appropriée pour une seule espèce d'intérêt. Il est calculé dans le pipeline BON in a Box en prenant cartes de répartition des espèces, des informations sur les gammes d'altitude et les catégories d'habitat de l'UICN pour déterminer la zone appropriée pour l'espèce. Ensuite, le pipeline utilise les données Global Forest Watch (GFW) (d'autres couverture du sol couches et des options pour saisir les données utilisateur seront bientôt ajoutées) pour calculer la zone et les scores de connectivité par espèce. Pour le score de la superficie à l'aide des données GFW, il est recommandé d'utiliser uniquement des espèces forestières et de commencer l'année au plus tôt 2000. La perte de forêt est détectée par année et soustraite de la couche forestière initiale de 2000 répartie dans le carte de répartition de l'espèce et filtrée par plages d'altitude. Cette couche est ensuite utilisée pour créer un raster avec les distances aux bords de l'habitat et la valeur moyenne pour la zone est utilisée comme score de connectivité. Le score de l'habitat et de la connectivité est combiné pour former le SHS. Pour calculer le SHI, le SHS pour chaque espèce est moyen et pour calculer le Steward’s SHI, il est également pondéré par la proportion de l'aire de répartition de l'espèce qui se trouve dans le zone d'étude.

### Sorties du pipeline

- **Espèces:** Liste des espèces d'intérêt pour lesquelles le SHI a été calculé.

- **Carte de répartition d'experts:** Polygone de la zone prévue pour les espèces d'intérêt.

- **Habitat par pas de temps :** Cartes raster de l'habitat pour chaque point de temps.

- **Carte raster du changement forestier :** Cartes des zones qui ont perdu leur habitat, ont gagné leur habitat et n'ont connu aucun changement au cours de la période spécifiée.

- **Tableau SHS :** Un fichier TSV contenant le score de surface, le score de connectivité et SHS par pas de temps pour chaque espèce. Pourcentage de variation, 100 % étant égal à l'année de référence.

- **SHS carte:** Figure montrant une carte indiquant les changements dans l'habitat au fil du temps, pour chaque espèce.

- **Séries chronologiques SHS :** graphique du score de connectivité, du score de l'habitat et du SHS dans le temps. Le sorties du pipeline sépare le graphiques pour chaque espèce.

- Tableau SHI :** Tableau avec les valeurs SHI et Steward’s SHI pour la zone d'étude complète.

- **Séries chronologiques SHI :** graphique du score SHI composite au fil du temps, 100% étant égal à l'année de référence.

- **La série SHI de Steve:** graphique de Steward’s SHI dans le temps. Steward’s SHI est pondéré par la proportion de l'aire de répartition de l'espèce qui se trouve dans le zone d'étude.

## Exemple
**Exemple d'exécution:** Voir un exemple d'exécution SHI ici dans les [Interface d'exécution](https://pipelines-results.geobon.org/pipeline-form/_2025-10-16%3ESpeciesHabitatIndex%3ESHI_pipeline/6cc8d65e413c341d251ea2550dadeacc) et [Visualiseur](https://pipelines-results.geobon.org/viewer/_2025-10-16%3ESpeciesHabitatIndex%3ESHI_pipeline%3E6cc8d65e413c341d251ea2550dadeacc).

## Dépannage
### Erreurs courantes :
- `Error: Script "data > Get species range map": ========== No range map available from expert source database ========== ` : si vous rencontrez cette erreur, cela signifie qu'il n'y a pas d'expert disponible cartes de répartition de l'UICN, du Ministère de l'Environnement du Québec (QC).  

    Vérifiez que votre espèce est répertoriée dans la table de recherche de la source avant de courir:

    - UICN (Union internationale pour la conservation de la nature) : mammifères, amphibiens, reptiles et quelques plantes (seulement plantes avec UICN cartes de répartition numérisé). [Liste des espèces (colonne "binomial")](https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/IUCN_rangemaps/iucn_fid_binomials.csv)

    - MOL (Map of Life): mammifères seulement. [Liste des espèces (colonne "sciname")](https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/mol_range_maps/mol_mammals.csv)

    - QC (Ministère de l'Environnement du Québec) : mammifères, reptiles et amphibiens, Québec seulement. Tapez des noms sans accents. [Liste des espèces (colonne "NOM_SCIENT")](https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/qc_range_maps/qc_range_maps.csv)

    Les oiseaux ne sont actuellement disponibles auprès d'aucune source.

- `Error: Script "data > Load from STAC": CRS is in degrees and resolution is in meters.`: si vous obtenez cette erreur, assurez-vous que SCR et résolution correspondent. Par exemple, SCR en degrés: EPSG:4326 ou SCR en mètres: EPSG:8857

## Références
Brooks, T. M., Pimm, S. L., Akçakaya, H. R., Buchanan, G. M., Butchart, S. H. M., Foden, W., Hilton-Taylor, C., Hoffmann, M., Jenkins, C. N., Joppa, L., Li, B. V., Menon, V., Ocampo-Peñuela, N., & Rondinini, C. (2019). Measuring Terrestrial Area of Habitat (AOH) and Its Utility for the IUCN Red List. Trends in Ecology & Evolution, 34(11), 977–986. [https://doi.org/10.1016/j.tree.2019.06.009](https://doi.org/10.1016/j.tree.2019.06.009)

Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. [https://doi.org/10.1038/s41559-021-01620-y](https://doi.org/10.1038/s41559-021-01620-y)



