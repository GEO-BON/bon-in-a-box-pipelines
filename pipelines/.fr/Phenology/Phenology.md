_Auteurs: Jory Griffith, Laetitia Tremblay_

Statut de révision: En développement

## Présentation
La phénologie est l'un des caractères de l'espèce EBVs. Il décrit la présence, l'absence, l'abondance ou la durée des activités saisonnières des organismes. Ce pipeline utilise le paquet de python openEO pour extraire la phénologie couches de la couche de phénologie de l'écosystème de l'espace de données Copernicus. Le raster a des valeurs pour l'indice de phénologie végétale (IPP), qui est un indice de végétation qui aide à estimer la santé de la végétation et l'activité photosynthétique tout au long de la saison de croissance. Il est plus directement lié à la phénologie végétale que d'autres indices de végétation comme NDVI et ne sature pas dans des conditions de biomasse élevées. Elle est calculée avec une réflectance proche de l'infrarouge, qui est fortement reflétée par une végétation saine. Vous pouvez en savoir plus sur la phénologie couches [ici](https://land.copernicus.eu/en/dataset-catalog). Le script tire la phénologie annuelle couches en utilisant openEO et les rééchantillonne à la résolution spatiale de choix, calcule statistiques sommaires sur un pays ou une région d'intérêt, et soustrait la rasters pour regarder le changement au fil du temps.

## Utilisations
Ce pipeline peut être utilisé pour regarder la Phénologie EBV. Il peut également servir d'intrant pour les pipelines subséquents, comme les modèles de distribution des espèces.

## Limites du pipeline

- Phénologie couches sont disponibles uniquement pour les pays d'Europe.
- Le pipeline utilise une résolution très fine, donc il faut beaucoup de temps pour fonctionner sur de grandes zones.

## Avant de commencer
Le pipeline nécessite une clé API pour l'écosystème Copernicus. Pour acquérir une clé API, visitez le CDSE [site web](https://dataspace.copernicus.eu/analyse/openeo).

## Exécution du pipeline

### Entrées du pipeline

- **Emprise et SCR :** l'utilisateur doit sélectionner un emprise et système de coordonnées de référence (SCR) à utiliser pour l'analyse. Cela peut être fait en utilisant le sélecteur pour sélectionner un pays et/ou une région, ou pour saisir/draper un emprise personnalisé. Ensuite, un SCR approprié peut être sélectionné dans le menu déroulant correspondant.

- **Saison d'intérêt :** saison pour laquelle effectuer l'analyse phénologique. Peut être soit la saison1 ou la saison2, où la première est la première saison de croissance (printemps et début de l'été) et la deuxième saison de croissance (fin d'été et automne).

- **Tables:** bandes raster d'intérêt pour les calculs.

- **Résolution spatiale :** l'utilisateur peut sélectionner la résolution spatiale du rasters. Cela doit être dans les mêmes unités que le système de coordonnées de référence (mètres pour les systèmes de référence projetés et degrés pour les systèmes de référence en longueur lat). Pour utiliser la résolution spatiale originale de couches (10m x 10m), l'utilisateur doit laisser cette entrée vide. Dans ce cas, le SCR sélectionné doit être EPSG:4326.

- **Année de début:** cette entrée est facultative. L'utilisateur peut sélectionner une date de début pour la série chronologique phénologique, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse à toutes les dates disponibles, l'utilisateur doit laisser cette entrée vide. Année de début pour les séries chronologiques phénologiques.

- **Année de fin:** cette entrée est facultative. L'utilisateur peut sélectionner une date de fin pour les séries temporelles phénologiques, au format YYY ou YYYY-MM-DD. Pour effectuer l'analyse à toutes les dates disponibles, l'utilisateur doit laisser cette entrée vide.

- **Fonction d'agrégation:** l'utilisateur peut choisir quelle fonction utiliser pour agréger spatialement les données phénologiques. Peut être moyen, maximum ou minimum (min). Le pipeline retournera une couche avec les valeurs résumées sur la période d'intérêt de chaque pixel. Cette entrée sera ignorée s'il n'y a pas besoin d'agrégation.

### Étapes du pipeline

#### **1. Récupération du polygone de la zone d'intérêt**
Cette étape renvoie le polygone pour le pays, la région ou la zone d'intérêt. Si un pays ou une région a été sélectionné, il tire le polygone du pays ou de la région en utilisant [Fieldmaps](https://fieldmaps.io/) et sorties comme GeoPackage, projeté dans le SCR d'intérêt. Si l'utilisateur entre un emprise personnalisé, il retournera un polygone fabriqué à partir de ce emprise.

#### **2. Résumé de la phénologie**
Cette étape résume les données phénologiques annuelles du pays d'intérêt en utilisant la couche phénologique de l'écosystème spatial de données Copernicus. Le client Python openEO est utilisé pour envoyer un travail à openEO. Le raster a des valeurs pour l'indice de phénologie végétale (IPP), qui est un indice de végétation qui aide à estimer la santé de la végétation et l'activité photosyntehtique tout au long de la saison de croissance. Il est plus directement lié à la phénologie végétale que d'autres indices de végétation comme NDVI, et ne sature pas dans des conditions de biomasse élevée. Elle est calculée avec une réflectance proche de l'infrarouge, qui est fortement reflétée par une végétation saine.

#### **3. Calcul du changement phénologique**
Cette étape calcule la différence dans le couches de la phénologie raster couches du année de début au année de fin, ou pour tous les couches disponibles si aucune date n'est sélectionnée, pour montrer la distribution spatiale des changements de phénologie.

### Sorties du pipeline

- **Pays:** pays d'intérêt, s'il est choisi.

- **Région:** région d'intérêt, si sélectionnée.

- **Phénologie rasters:** rasters de phénologie couches, avec un raster par an dans la plage de temps d'entrée. Sera soit le raster couches brut ou rééchantillonné à l'entrée de résolution spatiale par l'utilisateur.

- **Modification des paramètres phénologiques :** carte raster du changement phénologique du année de début au année de fin. Le année de fin est soustrait du année de début, de sorte que les valeurs plus grandes indiquent une plus grande diminution de la valeur donnée au fil du temps.

- **Graphique de changement phénologique:** graphique des valeurs phénologiques résumées dans le temps pour les bandes d'intérêt.

- **Statistiques de zone:** valeurs résumées sur le pays/région d'intérêt sur la base de l'entrée fonction d'agrégation par l'utilisateur, pour chaque année pour chaque tranche d'intérêt.

## Exemple
**Exemple d'exécution:** Voir un exemple Phénologie exécuté ici dans les [Interface d'exécution](https://pipelines-results.geobon.org/pipeline-form/_2025-10-16%3EPhenology%3Ephenology_EO/f08ed95a9538d87c7303027390889fba) et [Visualiseur](https://pipelines-results.geobon.org/viewer/_2025-10-16%3EPhenology%3Ephenology_EO%3Ef08ed95a9538d87c7303027390889fba).

## Dépannage
La phénologie couches sont une résolution fine, donc les tirer dans la résolution originale peut prendre une quantité importante de temps et d'espace sur votre ordinateur.

## Références
Copernicus Land Monitoring Service. (2024). High Resolution Vegetation Phenology and Productivity: Plant Phenology Index (raster 10 m), version 1 revision 1 [Dataset]. European Union. https://land.copernicus.eu/en/access-data/copernicus-services-catalogue/high-resolution-vegetation-phenology-and-productivity-1


