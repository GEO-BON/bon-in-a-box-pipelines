_Auteurs: Jory Griffith, Guillaume Larocque, Laetitia Tremblay, Jean-Michel Lord_

Statut de révision : révision

Révisé par: Santiago Saura, Oscar Godinez-Gomez, Camilo Andrés Correa-Ayram, Teresa Goicolea, Corey Ruha


nom: Protected Connected Index (ProtConn)


## Présentation

Le Protected Connected Index (ProtConn) est un indicateur clé au sein du Cadre mondial de la biodiversité de Kunming-Montréal (GBF) pour évaluer les progrès vers les objectifs A et 3 qui visent à protéger 30 % de la planète grâce à des réseaux bien connectés d'ici 2030. ProtConn quantifie le pourcentage d'un pays ou d'une région où aires protégées est effectivement connecté, ce qui permet le déplacement des espèces et le flux écologique.

ProtConn mesure à quel point une région est protégée et connectée (Saura et al. 2017, 2018). ProtConn est calculé en évaluant l'arrangement spatial de aires protégées pour déterminer la facilité avec laquelle les espèces peuvent se déplacer entre elles dans un paysage. Il traite aires protégées comme "nodes" et le mouvement potentiel entre eux comme "links", mesurant la probabilité qu'une espèce avec une distance de dispersion donnée puisse voyager entre aires protégées. Cette probabilité est calculée entre les bords les plus proches du aires protégées adjacent en utilisant un noyau de dispersion exponentielle négative, où la distance de dispersion d'entrée est la médiane (c'est-à-dire où la probabilité de dispersion est de 0,5). La valeur finale du ProtConn est exprimée en pourcentage du zone d'étude total, divisé en pourcentages représentant la connectivité à l'intérieur du AP, entre les différents AP et entre les frontières internationales. Pour en savoir plus sur la méthode ProtConn, voir Saura et al. 2017, 2018 et 2019.

Le pipeline utilise le paquet «Makurhini» (Godinez-Gomez et al. 2026) pour calculer les paramètres ProtConn. Le pipeline peut être exécuté avec des données de la base de données mondiale de aires protégées (UNEP-WCMC et UICN 2026) tirées pour un pays ou une région spécifique dans le pipeline, des fichiers de forme personnalisés de aires protégées téléchargés par l'utilisateur, ou une combinaison des deux. Cela permet aux utilisateurs d'évaluer ProtConn à la fois actuellement et avec l'ajout du futur aires protégées. ProtConn peut être calculé au niveau du pays ou de la région.

## Utilisations

ProtConn peut être utilisé pour évaluer les progrès actuels vers les buts A et 3 du FBG. Le pipeline peut également être utilisé pour comparer la connectivité de différents aires protégées proposés, aidant à la planification et à la conception. Le pipeline peut être exécuté avec une combinaison de aires protégées actuel de WDPA et de polygones d'entrée utilisateur des sites aire protégée proposés, permettant aux utilisateurs d'évaluer différents plans pour l'expansion de aire protégée.

## Limites du pipeline

* Sur les ensembles de données plus grands, le pipeline est lent et utilise beaucoup de mémoire, en particulier avec des distances de dispersion d'entrée plus grandes ou pour les pays avec beaucoup de aires protégées.

* Actuellement, le pipeline ne tient pas compte de la résistance du paysage (c.-à-d. si les terres entre aires protégées sont facilement traversées par des espèces).

## Avant de commencer

Aucune clé API n'est nécessaire pour exécuter ce pipeline.

Si vous souhaitez lancer le pipeline avec un polygone personnalisé pour votre zone d'étude, entrez votre chemin de fichier à partir du dossier de données utilisateur dans la boîte d'entrée « polygone de zone d'étude ».

Si vous souhaitez exécuter le pipeline avec une combinaison de polygones aire protégée personnalisés et de données WDPA, assurez-vous que vos données sont au format GeoPackage et entrez le chemin de fichier dans l'entrée « polygone de aires protégées ».

Si vous souhaitez lancer l'analyse uniquement avec des données aire protégée personnalisées, veuillez utiliser le pipeline `ProtConn Analysis with custom PAs`.


## Exécution du pipeline

### Entrées du pipeline

BON in a Box contient un pipeline pour calculer ProtConn pour un pays ou une région d'intérêt donné. Le pipeline comporte les entrées utilisateur suivantes:

- **Emprise et SCR :** l'utilisateur doit sélectionner un emprise et système de coordonnées de référence (SCR) à utiliser pour l'analyse. Cela peut être fait en utilisant le sélecteur pour sélectionner un pays et/ou une région, ou pour saisir/draper un emprise personnalisé. Ensuite, un SCR approprié peut être sélectionné dans le menu déroulant correspondant. **Le SCR doit être projeté (c.-à-d. les unités associées doivent être en mètres).**

- **Polygon de zone d'étude:** c'est une entrée optionnelle pour ajouter un fichier zone d'étude personnalisé, qui remplacera le polygone généré à partir de l'entrée emprise et SCR. Le fichier zone d'étude personnalisé doit être au format GeoPackage et ajouté au dossier de données utilisateur de votre dépôt local. Cette entrée doit être le chemin vers le fichier dans les données utilisateur (par exemple /userdata/study area polygon.gpkg).

- **Polygon de aires protégées:** c'est une entrée optionnelle et ne devrait être utilisé que si l'utilisateur veut utiliser des données aire protégée personnalisées, par exemple s'il veut calculer ProtConn pour aires protégées ou aires protégées qui ne sont pas encore dans WDPA. Si vous utilisez le pipeline `ProtConn Analysis with WDPA`, cette entrée est facultative et tout fichier ajouté sera combiné avec les données WDPA du pays d'intérêt. Si vous utilisez le pipeline `ProtConn Analysis with custom PAs`, cette entrée est obligatoire et le pipeline analysera uniquement les polygones aire protégée d'entrée utilisateur.

- **Transfrontalier tampon:** l'utilisateur doit sélectionner un tampon pour tirer le aires protégées transfrontière. Le tampon tirera aires protégées à cette distance de la frontière du pays ou emprise dans l'unité du système de coordonnées de référence. Si vous tirez des données WDPA avec un emprise personnalisé, le tampon ne sera pas appliqué. Il est recommandé que l'utilisateur choisisse une distance transfrontière 5 fois supérieure au seuil de distance le plus élevé, ce qui correspond à une probabilité de dispersion de ~0.03. La valeur par défaut est zéro.

- **Date Nom de la colonne :** c'est une entrée optionnelle à utiliser avec un fichier de données aire protégée personnalisé. L'utilisateur peut indiquer le nom de la colonne dans le fichier qui spécifie quand le aire protégée a été créé (laisser vide si seulement en utilisant des données WDPA).

- **Seuil d'analyse de la distance :** l'utilisateur peut spécifier une ou plusieurs distances de dispersion en fonction des espèces qui les intéressent. Les distances de dispersion communes sont de 1 000 mètres (1km), 10 000 mètres (10km) et 100 000 mètres (100 km). La distance de dispersion est la médiane du noyau de dispersion exponentielle négative, ce qui signifie qu'à cette distance il y a une probabilité de dispersion de 0,5. Notez que les distances de dispersion plus grandes seront plus intensives en calcul.

  ![Probabilité de dispersion](https://github.com/user-attachments/assets/5a867368-12a3-4402-aa1d-a034b9dc7962)

- **Séries horaires :** l'utilisateur peut spécifier s'il souhaite calculer une série chronologique graphique de valeurs ProtConn en fonction de la date de l'établissement AP. L'émission des séries chronologiques réduit les coûts de mémoire et de calcul.

- **Année de début:** le année de début de la série chronologique des valeurs ProtConn. Les séries chronologiques calculeront ProtConn pour le aires protégées établi au plus tard l'année choisie, et compteront jusqu'à l'année limite par l'intervalle spécifié. Toute date manquante dans le fichier aire protégée sera automatiquement attribuée à cette année. Cela peut être laissé vide ou sera ignoré si l'option série chronologique n'a pas été sélectionnée.

- **Année limite :** l'utilisateur peut spécifier une année pour l'analyse. L'analyse ne calculera que les valeurs de aires protégées établies avant cette année limite. Par exemple, une entrée de 2000 calculera ProtConn seulement pour AP qui ont été désignés avant l'an 2000.

- **Intervalle d'année :** l'intervalle d'année pour la série chronologique des valeurs ProtConn. Par exemple, une entrée de 10 calculera les valeurs de ProtConn tous les 10 ans. Cela peut être laissé vide ou sera ignoré si l'option série chronologique n'a pas été sélectionnée.

- **Seuil de taille AP :** l'utilisateur doit saisir un seuil de taille pour AP, en mètres carrés. Aires protégées plus petit que cette zone sera enlevé. Un seuil de 1 000 m2 a été utilisé dans Saura et al. 2017 parce qu'à des échelles plus grandes, aires protégées de moins de 1 000 m2 n'a pas d'impact important sur les valeurs de ProtConn. L'élimination du petit aires protégées accélère significativement le calcul et est recommandée pour les grandes surfaces. Pour éviter de filtrer AP par seuil de taille, saisissez une valeur de 0.

- **Les types de statut juridique AP à inclure:** l'utilisateur peut choisir les types de statut juridique de données WDPA à inclure dans l'analyse. Cette entrée n'est pertinente que si l'on utilise des données WDPA. Le aires protégées peut avoir un statut juridique de `Proposed`, `Inscribed`, `Adopted`, `Designated` ou `Established`.
  - `Proposed` signifie que le site est en voie d'être reconnu par des moyens légaux ou autres efficaces. Il peut encore être géré comme un aire protégée pendant ce processus.
  - `Inscribed` signifie qu'il est inscrit sur une liste internationale (p. ex. Patrimoine mondial). Cela peut se chevaucher avec désigné.
  - `Adopted` signifie qu'il s'agit d'un aire protégée spécialement d'importance marine (SPAMI) créé dans le cadre de la Convention de Barcelone, axé sur la protection du milieu marin et des régions côtières de la Méditerranée.
  - `Designated` signifie qu'il est officiellement établi en vertu du droit ou de la politique nationale ou internationale.
  - `Established` signifie qu'il est protégé et géré, mais peut-être manque de désignation juridique formelle.

- **Inclure les réserves de biosphère de l'UNESCO:** l'utilisateur peut spécifier s'il souhaite inclure l'homme de l'UNESCO et les réserves de biosphère dans l'analyse ou non. Ils servent de sites d'apprentissage pour le développement durable et combinent la conservation de la biodiversité avec l'utilisation durable des ressources naturelles et le développement durable. Elles peuvent ne pas être protégées par la loi et ne pas être entièrement conservées, car elles sont souvent utilisées pour le développement ou les établissements humains. À l'exclusion de celles-ci, l'ensemble de données se limitera à respecter des normes de conservation plus strictes. Cette entrée n'est pertinente que si les données WDPA sont utilisées.

- **Tampon points aire protégée :** l'utilisateur peut spécifier s'il veut des points tampon aire protégée. Pour tout aires protégées représenté comme un seul point au lieu de polygones, cela créera un cercle autour du point qui est égal à la zone signalée. Si elle n'est pas cochée, tous les aires protégées représentés en points seront supprimés. Cette entrée n'est pertinente que si l'on utilise des données WDPA.

- **Inclure AMCE :** l'utilisateur peut préciser s'il souhaite inclure d'autres mesures de conservation efficaces basées sur la zone (AMCE) dans l'analyse ou non. Ces zones ne sont pas officiellement désignées aires protégées mais continuent d'atteindre des résultats en matière de conservation. Cette entrée n'est pertinente que si l'on utilise des données WDPA.

- **Inclure le aires protégées marin et côtier :** l'utilisateur peut spécifier s'il veut inclure le aires protégées marin dans l'analyse ou non. Notez que l'analyse est encore limitée aux limites du polygone zone d'étude. Cette entrée n'est pertinente que si l'on utilise des données WDPA.

- **Inclure les valeurs manquantes pour la date :** l'utilisateur peut spécifier comment les valeurs manquantes pour la date doivent être traitées dans l'analyse des séries chronologiques. Si la case est cochée, aires protégées avec des valeurs manquantes pour la date d'établissement sera inclus dans l'analyse des séries chronologiques et assigné à la valeur choisie pour année de début. Si elles ne sont pas cochées, ces aires protégées seront omis de l'analyse des séries chronologiques (à noter qu'elles seront toujours incluses dans l'analyse principale).

### Étapes du pipeline

#### **1. Obtenir aires protégées de la base de données mondiale sur aires protégées (WDPA)**

Cette étape récupère aires protégées dans le pays/région d'intérêt de la base de données WDPA à l'aide de l'API WDPA. (Cette étape est ignorée si vous utilisez uniquement des données AP personnalisées.)

#### **2. Obtenir le polygone de la zone d'intérêt**

Cette étape renvoie le polygone pour le pays, la région ou la zone d'intérêt. Si un pays/région a été sélectionné, il tire le polygone pays/région en utilisant [Fieldmaps](https://fieldmaps.io/) et sorties comme un GeoPackage projeté dans le SCR d'intérêt. Si l'utilisateur entre un emprise personnalisé, il retourne un polygone fabriqué à partir de ce emprise.

#### **3. Nettoyage des données aires protégées**

Cette étape nettoie les données récupérées du WDPA en corrigeant les problèmes de géométrie et en filtrant les entrées souhaitées. Cette étape produit également le aires protégées par le zone d'étude (cette étape est ignorée si vous utilisez uniquement des données AP personnalisées).

#### **4. Effectuer l'analyse ProtConn**

Cette étape effectue l'analyse ProtConn sur le aires protégées d'intérêt. ProtConn est calculé en créant une matrice par paire des distances entre les bords les plus proches de chaque aire protégée. Ensuite, il calcule la probabilité qu'une espèce se disperse entre ces aires protégées en utilisant un noyau de dispersion exponentielle négatif avec la distance d'entrée attribuée à une probabilité de 0,5. Cela signifie que si le aires protégées est très proche l'un de l'autre, il y a une forte probabilité que les espèces puissent se disperser entre elles, mais cette probabilité se dégrade de façon exponentielle avec une distance croissante. Différentes distances de dispersion peuvent être spécifiées en fonction des espèces d'intérêt, car de très petites espèces telles que les rongeurs ne peuvent se disperser jusqu'aux grands mammifères tels que les cerfs, de sorte que la connectivité ne serait pas la même pour ces groupes. Ensuite, la probabilité de dispersion entre chaque paire de aires protégées est multipliée par la surface du aires protégées, et le résultat de ce produit est résumé pour toutes les paires et divisé par la surface du zone d'étude.

### Sorties du pipeline

- **Aires protégées:** aires protégées sur lequel ProtConn est calculé. La superposition de aires protégées a été fusionnée pour accélérer les calculs.

- **ProtConn résultats:** le pipeline donne un tableau avec plusieurs mesures:
  - Non protégé - pourcentage de zone d'étude non couvert par un aire protégée
  - ProtConn - pourcentage de zone d'étude couvert par aires protégées bien connecté
  - ProtUnconn - pourcentage de zone d'étude qui est couvert par aires protégées qui ne sont pas bien connectés
  - ProtConn Unprot - Pourcentage des terres reliées protégées qui peuvent être atteintes en passant par des zones non protégées. Il comprend les mouvements entre AP qui se produisent entièrement à travers des terres non protégées et d'autres qui traversent des terres non protégées dans les tronçons initial et final, mais qui peuvent utiliser certaines terres protégées entre les deux. La valeur de cette fraction sera plus faible lorsque AP sera séparé par de plus grandes étendues de terres non protégées, ce qui rend les déplacements inter-AP moins probables, particulièrement lorsque les distances à parcourir par des terres non protégées sont importantes par rapport à la distance de dispersion.
  - ProtConn Within - Pourcentage du terrain connecté protégé qui peut être atteint en se déplaçant seulement à l'intérieur de l'individu AP
  - ProtConn Contig - Pourcentage des terres reliées protégées qui peuvent être atteintes en passant par des ensembles de AP immédiatement adjacents (contitueux) sans traverser de terres non protégées.

- **ProtConn résultat graphique:** donut graphique du pourcentage de zone d'étude qui est protégé et non connecté, et protégé et connecté pour chaque distance de dispersion d'entrée (en mètres).

- **Résultats des séries chronologiques ProtConn :** tableau des séries chronologiques des valeurs ProtConn et ProtUnconn, calculées à l'intervalle de temps spécifié.

- **ProtConn séries chronologiques graphique:** graphique montrant la variation du pourcentage de zone protégée et le pourcentage de zone protégée et connectée dans le temps, à l'intervalle de temps choisi, par rapport aux buts de Kunming-Montréal GBF.

- **polygone zone d'étude:** polygone du zone d'étude choisi.

## Exemples

Exemple d'un exécution du pipeline avec des données WDPA : [Visualiseur de résultats](http://pipelines-results.geobon.org/viewer/_2026-05-06%3EProtconn-pipeline%3EProtConn_pipeline%3ErgKj9pkfr2WYcX2U3L6seYkqqPXJ) et [détails de l'exécution](https://pipelines-results.geobon.org/pipeline-form/_2026-05-06%3EProtconn-pipeline%3EProtConn_pipeline/rgKj9pkfr2WYcX2U3L6seYkqqPXJ)

Exemple d'un exécution du pipeline avec des données utilisateur : [Visualiseur de résultats](https://pipelines-results.geobon.org/viewer/_2026-05-06%3EProtconn-pipeline%3EProtConn_pipeline_userdata%3ECuX6Sktt9wSZcPb885-LCHZQ9ODI) et [détails de l'exécution](https://pipelines-results.geobon.org/pipeline-form/_2026-05-06%3EProtconn-pipeline%3EProtConn_pipeline_userdata/CuX6Sktt9wSZcPb885-LCHZQ9ODI)
  
</a>

Exemple de exécution du pipeline avec données utilisateur combinées et données WDPA : [Visualiseur de résultats](https://pipelines-results.geobon.org/viewer/_2026-05-06%3EProtconn-pipeline%3EProtConn_pipeline%3EF7Kx9xgMeuerWHxh-p-tBG_PxM4z) et [détails de l'exécution](https://pipelines-results.geobon.org/pipeline-form/_2026-05-06%3EProtconn-pipeline%3EProtConn_pipeline/F7Kx9xgMeuerWHxh-p-tBG_PxM4z)

## Dépannage

**Erreurs communes:**

- `Error: Could not retrieve protected areas from WDPA`: si vous rencontrez cette erreur, cela signifie que l'API WDPA n'est pas en mesure de récupérer les données pour le pays/région d'intérêt. Cela arrive parfois avec de très grands ensembles de données et est un problème avec l'API elle-même, pas le pipeline.

- `Error: Script produced no results. Check log for errors and make sure that the script calls biab_output.`: si vous rencontrez cette erreur et que vous exécutez ProtConn pour une grande zone avec beaucoup de aires protégées, il est probable que Docker a terminé le processus parce que vous avez épuisé la RAM de l'ordinateur. Vous pouvez avoir besoin de lancer l'analyse avec des zones plus petites ou sur un ordinateur avec plus de RAM.

- `There is no country or region polygon for this bounding box`: si vous rencontrez cette erreur, vous devez sélectionner un emprise qui comprend au moins un pays ou une région. La plus petite unité sur laquelle ProtConn peut actuellement être calculé est une région.

## Références

Godínez-Gómez, O., Correa Ayram, C.A., Goicolea, T., Saura, S. 2026. Makurhini: An R package for comprehensive analysis of landscape fragmentation and connectivity. Environmental Modelling & Software. https://doi.org/10.1016/j.envsoft.2026.106981.

Saura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2017. “Protected Areas in the World’s Ecoregions: How Well Connected Are They?” Ecological Indicators 76:144–58. doi:10.1016/j.ecolind.2016.12.047.

Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2018. “Protected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.” Biological Conservation 219:53–67. doi:10.1016/j.biocon.2017.12.020.

Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2019. “Global Trends in Protected Area Connectivity from 2010 to 2018.” Biological Conservation 238:108183. doi:10.1016/j.biocon.2019.07.028.

UNEP-WCMC and IUCN (2026), Protected Planet: The World Database on Protected Areas (WDPA), Cambridge, UK: UNEP-WCMC and IUCN.



