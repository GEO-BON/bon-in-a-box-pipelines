# Indice d'intégrité de la biodiversité
### Auteur(s): Jory Griffith
#### Révisé par: En développement

## Présentation
Le Indice d'intégrité de la biodiversité (BII) est une mesure conçue pour évaluer le degré d'intégrité et de fonctionnement des écosystèmes par rapport à leur état naturel. Il mesure l'abondance et la diversité des espèces dans une région donnée par rapport à ce qui serait attendu dans un écosystème non perturbé. Le BII explique divers facteurs, notamment la perte, la fragmentation et la dégradation de l'habitat, offrant une vue d'ensemble de la santé de la biodiversité. Une valeur BII plus élevée indique un écosystème plus intact avec plus de diversité et d'abondance d'espèces, tandis qu'une valeur plus faible suggère une perturbation écologique importante. Le Indice d'intégrité de la biodiversité est un indicateur complémentaire dans le GBF. Le BII a été créé par le Natural History Museum et utilise sa base de données PREDICTS, qui regroupe les données d'études comparant la biodiversité terrestre à des sites présentant des niveaux de pression humaine variables. La base de données sert à établir un état de référence en utilisant les profils de biodiversité dans les habitats à niveaux de perturbation minimes. Ensuite, il attribue des scores de sensibilité à chaque espèce en fonction de leur vulnérabilité à la pression humaine. L'intégrité est calculée en comparant l'abondance des espèces observées dans une zone donnée à ce qui est attendu dans des conditions de référence à faible impact humain. Il contient actuellement plus de 3 millions d'enregistrements provenant de plus de 26 000 sites répartis dans 94 pays, représentant un éventail diversifié de plus de 45 000 espèces de plantes, d'invertébrés et de vertébrés.

## Cas d'utilisation/Contexte
Le Indice d'intégrité de la biodiversité est un indicateur complémentaire dans le GBF. Ce pipeline peut être utilisé pour calculer statistiques sommaires et tracer une série chronologique de la couche de résolution BII de 10 km pour un pays ou une région donné. Le BII est exprimé en pourcentage, les pourcentages plus élevés étant plus intacts.

## Limites du pipeline
Le pipeline ne modélise pas le Indice d'intégrité de la biodiversité à partir des données, il calcule statistiques sommaires sur la couche globale déjà calculée à 10x10km de résolution. Par conséquent, vous ne pouvez pas personnaliser le modèle ou saisir des données personnalisées. De plus, comme BII est une couche de données modélisées, les valeurs peuvent être moins précises dans les zones où il y a un manque de données. Pour en savoir plus sur la base de données PREDICTS, visitez le [page sur le site Natural History Museum](https://www.nhm.ac.uk/our-science/research/projects/predicts/science.html).

## Avant de commencer
Il n'y a pas de données ou de clés API nécessaires pour cette analyse. Pour voir la couche globale, allez à notre [Catalogue STAC](https://stac.geobon.org/viewer/bii_nhm/bii_nhm_10km_2020).

## Exécution du pipeline

### Entrées du pipeline
Le Natural History Museum a créé raster couches de BII depuis l'an 2000. BON in a Box a un pipeline pour calculer statistiques sommaires et tracer une série chronologique à partir de ces couches dans un pays, une région, ou zone d'étude personnalisé d'intérêt. Le pipeline possède les intrants suivants:

- **Pays:** pays d'intérêt.

- **État/Province :** région d'intérêt.

- **Statistique sommaire:** l'utilisateur peut choisir le statistique sommaire pour BII (options : moyenne, médiane, mode) qui sera calculé pour le pays ou la région d'intérêt.

- **Année de début pour la comparaison BII raster :** référence BII année pour le tracé raster.

- **Année de fin pour la comparaison BII :** couche BII pour la comparaison avec année de début.

- **Système de coordonnées de référence:** le système de coordonnées de référence de choix. Rechercher un SCR intéressant [ici](https://epsg.io/). Cela doit être un système de coordonnées de référence projeté (en mètres).

- **Résolution spatiale :** la résolution spatiale du rasters (en mètres). La résolution spatiale de la couche est de 10 x 10 km.

### Étapes du pipeline

#### **1. Récupération du pays emprise**
Cette étape récupère le emprise pour le pays/région d'intérêt en utilisant le pipeline `Get country bounding box`.

#### **2. Chargement des données du catalogue GEO BON STAC**
Cette étape extrait l'intégrité de la biodiversité mondiale couches de diverses collections sur le GEO BON Spatio Temporal Asset Catalog. Les couches sont en résolution EPSG: 4326 et 10x10 km, mais l'utilisateur peut spécifier d'autres systèmes de référence de coordonnées et résolutions spatiales.

#### **3. Calcul des statistiques zonales**
Cette étape calcule les statistiques zonales pour le raster couches obtenu à partir du catalogue GEO BON STAC sur le emprise de l'étape 1, en utilisant le package R exactextractr. L'utilisateur peut choisir quels types de statistiques zonales seront extraits.

#### **4. Calcul du changement BII**
Cette étape génère un raster du changement de BII entre les deux points temporels choisis. Le BII utilise la base de données PREDICTS pour établir un état de référence en utilisant les profils de biodiversité dans les habitats à niveaux de perturbation minimes. Ensuite, il attribue des scores de sensibilité à chaque espèce en fonction de leur vulnérabilité à la pression humaine. L'intégrité est calculée en comparant l'abondance des espèces observées dans une zone donnée à ce qui est attendu dans des conditions de référence à faible impact humain.

### Sorties du pipeline

- **Rasters:** l'utilisateur peut afficher tous les raster couches pour chaque année qui ont été utilisés pour générer le statistiques sommaires.

- **Statistique sommaire:** un tableau des valeurs statistique sommaire de BII sur plusieurs années.

- **variation du BII:** un carte raster du variation du BII entre les deux années choisies. Les chiffres plus élevés indiquent une plus grande perte de BII.

- **Pays:** région d'intérêt.

- **Région:** pays d'intérêt.

## Exemple
**Exemple d'exécution:** Voir un exemple d'exécution BII ici dans les [Interface d'exécution](https://pipelines-results.geobon.org/pipeline-form/_2025-10-16%3EBII%3EBII/d29bd8231a0ceefbd0fd14bc16e1e4cc) et [Visualiseur](https://pipelines-results.geobon.org/viewer/_2025-10-16%3EBII%3EBII%3Ed29bd8231a0ceefbd0fd14bc16e1e4cc).

## Dépannage
- La résolution spatiale du BII couches est de 10 x 10 km (10 000 m). Choisir une résolution spatiale inférieure à celle qui peut causer des problèmes avec le sorties du pipeline.

## Références
Adriana De Palma; Sara Contu; Gareth E Thomas; Connor Duffin; Sabine Nix; Andy Purvis (2024). The Biodiversity Intactness Index developed by The Natural History Museum, London, v2.1.1 (Open Access, Limited Release) [Data set]. Natural History Museum. https://doi.org/10.5519/k33reyb6

Newbold, T., Hudson, L. N., Arnell, A. P., Contu, S., De Palma, A., Ferrier, S., Hill, S. L. L., Hoskins, A. J., Lysenko, I., Phillips, H. R. P., Burton, V. J., Chng, C. W. T., Emerson, S., Gao, D., Pask-Hale, G., Hutton, J., Jung, M., Sanchez-Ortiz, K., Simmons, B. I., … Purvis, A. (2016). Has land use pushed terrestrial biodiversity beyond the planetary boundary? A global assessment. Science, 353(6296), 288–291. https://doi.org/10.1126/science.aaf2201



