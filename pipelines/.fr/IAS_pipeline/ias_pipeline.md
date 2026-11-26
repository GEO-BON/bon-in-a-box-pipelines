_Auteur(s): Rachel Mason, Saxbee Affleck, Manuela Gómez-Suárez, Hanno Seebens, Samara Manzin, Melodie McGeoch_

## Présentation
Les espèces exotiques envahissantes constituent une menace majeure pour la biodiversité. La réduction des taux d'introduction et d'établissement des espèces envahissantes est un élément important de la cible 6 du Cadre mondial de la biodiversité de Kunming-Montréal (GBF). 

Le pipeline recueille de l'information nationale sur les espèces exotiques et envahissantes et évalue les tendances à partir de leurs premiers dossiers documentés. Il combine les données nationales liste de référence du Registre mondial des espèces introduites et envahissantes (GRIIS) avec la base de données des espèces exotiques premiers signalements. 

Le pipeline applique le flux de travail de la standardisation et de l'intégration des données sur les espèces exotiques (SInAS) pour stabiliser et fusionner ces ensembles de données sources. Les noms d'espèces, les emplacements, les habitats, l'information occurrence et les dates du premier enregistrement sont normalisés avant la fusion des données GRIIS et premiers signalements. Les noms d'espèces et les classifications taxonomiques sont vérifiés par rapport à l'épine dorsale taxonomique GBIF. Les dossiers qui ne peuvent pas être entièrement normalisés sont documentés dans la qualité des données du pipeline sorties. 

Le pipeline crée une série chronologique annuelle d'espèces exotiques envahissantes premiers signalements pour le pays sélectionné. Un premier signalement représente la première détection documentée d'une espèce; il ne représente pas nécessairement l'année où l'espèce a été introduite, établie ou devenue envahissante.

En fonction de l'exhaustivité du premier enregistrement et du nombre d'années de conservation, le pipeline choisit l'une des quatre approches suivantes :
- aucune modélisation lorsque les données disponibles sont trop rares;
- une comparaison qualitative des premiers enregistrements et des profils d'observation GBIF;
- un ensemble réduit de modèles quantitatifs; ou 
- l'ensemble complet de modèles quantitatifs. 

Les approches quantitatives comprennent un modèle de Poisson naïf, un modèle de détection constante, un modèle Solow-Costello et un modèle d'échantillonnage qui utilise le volume d'enregistrement annuel GBIF comme indicateur indirect de l'effort d'observation. Le sorties décrit les hypothèses, l'ajustement, la tendance estimée, l'interprétation et les limites de chaque modèle. Pour de l'information sur l'estimation des taux d'introduction à partir des données du premier enregistrement, voir McGeoch et al. (2023) et Buba et al. (2024).

## Utilisations
Ce pipeline peut être utilisé pour:
- Compiler et normaliser les données GRIIS et premiers signalements nationales pour produire un ensemble de données nationales taxonomiquement normalisé des espèces exotiques et envahissantes.

- Identifier les dossiers non appariés, exclus ou potentiellement problématiques pour l'examen de la qualité des données. 

- Résumez et examinez les patrons temporels dans premiers signalements observé.

- Comparer les modèles avec différentes hypothèses sur le détectino et l'effort d'observation.

- Appuyer l'évaluation nationale et la communication de l'information relative à la cible 6 du Fonds mondial de développement

## Limites du pipeline
* Ce pipeline ne peut pas être exploité actuellement pour les pays suivants en raison de problèmes de données sources non résolus, de nom liste de référence ou de localisation : États-Unis d'Amérique (USA), Belgique (BEL), Thaïlande (THA), Eswatini (SWZ), Hongrie (HUN) et Norvège (NOR).

* Les relevés annuels GBIF sont utilisés comme approximation indirecte pour modifier l'effort d'observation. Le volume record de GBIF n'est pas une mesure directe de l'effort de relevé des espèces exotiques envahissantes. 

* Les résultats du modèle doivent être interprétés avec prudence, veuillez lire l'interprétation du modèle sorties et les documents énumérés ci-dessous pour obtenir des conseils. 

* La normalisation taxonomique automatisée et la normalisation des lieux ne peuvent pas résoudre tous les dossiers. Avant d'interpréter les résultats, les utilisateurs devraient examiner la qualité des données, la valeur inégalée et l'enregistrement exclu sorties. 

* Lorsqu'une date de premier enregistrement est fournie sous forme de fourchette, le pipeline utilise son année moyenne. Cette année estimée ne représente pas une date bien documentée.

* Les résultats dépendent des versions et de la couverture des données GRIIS, premiers signalements, GBIF et de configuration sous-jacentes. 

## Avant de commencer
Un compte GBIF gratuit est nécessaire pour obtenir les données d'observation GBIF utilisées par le pipeline. Add your GBIF username, password, and account email address to the `runner.env` file using the following environment variables: `GBIF_USER`, `GBIF_PWD`, and `GBIF_EMAIL`.

Les utilisateurs doivent prendre note des versions des bases de données source et du flux de travail utilisés pour une analyse. Toute modification du flux de travail, des tableaux de configuration ou des données sources devrait également être signalée pour soutenir la transparence et la reproductibilité.

Examiner la valeur inégalée, l'enregistrement exclu, l'appariement taxonomique, le conflit de fusion et d'autres données de qualité sorties avant d'interpréter les résultats.


## Exécution du pipeline
BON in a Box contient un pipeline pour analyser les profils temporels des espèces envahissantes et exotiques pour un pays ou une région d'intérêt donné. Le pipeline comporte les entrées utilisateur suivantes:

### Entrées du pipeline

- **Pays :** l'utilisateur doit choisir un pays pour l'analyse des espèces exotiques envahissantes. Cela peut être fait en sélectionnant un pays dans le menu déroulant.   

- **Année de début:** l'utilisateur doit sélectionner le année de début pour lequel obtenir des observations GBIF. Les enregistrements GBIF serviront de substitut à l'effort d'échantillonnage dans un pays donné. 

- **Année de fin:** l'utilisateur doit sélectionner le année de fin pour lequel obtenir des observations GBIF. Ceux-ci serviront de substitut à l'effort d'échantillonnage dans un pays donné

- **Règnes:** l'utilisateur doit sélectionner le règnes à conserver dans les deux datsets GRIIS et premiers signalements. Cela peut être fait en sélectionnant à partir du règnes disponible dans le menu déroulant. 

- **Types d'habitat :** l'utilisateur doit sélectionner les valeurs de l'habitat à conserver dans les ensembles de données GRIS et premiers signalements. Cela peut être fait en sélectionnant une valeur dans le menu déroulant. 

### Étapes du pipeline
#### **1. Obtenir des données premiers signalements**
Cette étape télécharge les données de la base de données sur les espèces exotiques premiers signalements qui indique quand une espèce envahissante a été enregistrée pour la première fois dans le pays choisi par l'utilisateur.

#### **2. Obtenir GRIIS liste de référence**
Cette étape télécharge les données nationales liste de référence du Registre mondial des espèces introduites et envahissantes (GRIIS) pour le pays sélectionné par l'utilisateur.

#### **3. Normalisation et nettoyage des ensembles de données**
Cette étape applique le processus de normalisation et d'intégration des données sur les espèces exotiques (SInAS) pour normaliser et nettoyer ces ensembles de données sources. 

#### **4. Obtention de GBIF occurrences d'espèces pour le pays d'intérêt**
Cette étape récupère les données de GBIF à l'aide de l'API GBIF. Les utilisateurs doivent avoir un nom d'utilisateur GBIF, un mot de passe et une adresse email de compte au fichier runner.env en utilisant les variables d'environnement suivantes : GBIF USER, GBIF PWD et GBIF EMAIL.

#### **5. Fusion des ensembles de données**
Cette étape applique le processus de normalisation et d'intégration des données sur les espèces exotiques (SInAS) pour fusionner ces ensembles de données. Les noms d'espèces et les classifications taxonomiques sont vérifiés par rapport à l'épine dorsale du taxonome GBIF. 

#### **6. Analyser les tendances des taux d'introduction des espèces exotiques envahissantes**
Cette étape choisit le modèle approprié pour calculer le taux d'introduction des IAS et de l'effectivité des enquêtes dans le pays choisi par l'utilisateur. 


### Sorties du pipeline

- **Ensemble de données fusionné SInAS :** Un ensemble de données décrivant l'espèce invasive taxons, son emplacement et ses moyens d'établissement à partir des ensembles de données fusionnés du GRIIS liste de référence et de la base de données premiers signalements

- **Rapport sur la qualité des données SInAS:** Le statut de contrôle de la qualité combiné, les valeurs inégalées et les conflits de fusion, y compris les mesures prises à la suite de la fusion des sources de données.  

- **SInAS enregistrements exclus:** La source complète des enregistrements exclus de la fusion des sources de données qui n'ont pas pu être standardisées selon le flux de travail SInAS.

- **SInAS résumé de l'exécution:** Les relevés originaux des espèces envahissantes de la base de données GRIIS liste de référence et premiers signalements ainsi que les relevés des enregistrements fusionnés après normalisation, nettoyage et contrôles de qualité.

- **Sorties du modèle:** Hypothèses, paramètres, statistiques d'ajustement, état de convergence, direction de tendance estimée, interprétation et mises en garde pour chaque option de modèle. Les tendances du premier enregistrement ne sont pas automatiquement équivalentes aux tendances de l'introduction.

- **Décision de modélisation:** Le raisonnement derrière le modèle qui a été rapporté. Cela comprend le scénario de données choisi, les critères d'adéquation, le niveau soutenu de la raison pour laquelle le modèle a été choisi, les directives d'interprétation, la portée partagée et les références. 

- **Résumé des données de modélisation:** Statistiques sur l'adéquation des données pour le pays sélectionné. L'exhaustivité du premier enregistrement est le pourcentage de GRIIS taxons envahissant partout où il y a une première année, ce n'est pas l'exhaustivité globale du liste de référence. 

- **Comparaison quantitative du modèle:** Les dossiers de découverte annuels adaptés des modèles avec des hypothèses de détection alternatives. Comparez statistiques d'ajustement seulement parmi les modèles convergents installés dans le même pays et les mêmes séries chronologiques.

- **Modèle qualitatif graphique:** Comparaison descriptive de l'IAS premiers signalements annuelle avec le proxy d'observation GBIF. Des modèles semblables peuvent indiquer un effet d'observation-effort; ce graphique n'est pas une estimation corrigée du taux d'introduction.

- **Interprétation qualitative du modèle :** Interprétation choisie à partir de la combinaison IAS-observation et l'effort d'enquête. Une tendance est classée comme stable lorsque sa pente de temps adaptée n'est pas significative à alpha = 0,05. Preuves et certitude accrue en matière de prévention et de gestion réussies (observations de la SAMU : diminution; efforts d'enquête : augmentation)

## Exemple


## Dépannage

**Erreurs communes:**

- `401 - Unauthorized` : cette erreur indique un défaut de connexion à l'API GBIF. C'est généralement parce que l'information sur le compte GBIF fournie n'est pas valide. 

## Références

Buba, Y. (2024). alien: Estimate Invasive and Alien Species (IAS) Introduction Rates [Dataset]. https://doi.org/10.32614/CRAN.package.alien

Buba, Y., Kiflawi, M., McGeoch, M. A., & Belmaker, J. (2024). Evaluating models for estimating introduction rates of alien species from discovery records. Global Ecology and Biogeography, 33(8), e13859. https://doi.org/10.1111/geb.13859

McGeoch, M. A., Buba, Y., Arlé, E., Belmaker, J., Clarke, D. A., Jetz, W., Li, R., Seebens, H., Essl, F., Groom, Q., García‐Berthou, E., Lenzner, B., Meyer, C., Vicente, J. R., Wilson, J. R. U., & Winter, M. (2023). Invasion trends: An interpretable measure of change is needed to support policy targets. Conservation Letters, 16(6), e12981. https://doi.org/10.1111/conl.12981
  
Seebens, H., & Gómez-Suárez, M. (2025). SInAS: A global dataset of native and alien distributions of alien species [Dataset]. Zenodo. https://doi.org/10.5281/ZENODO.17727120



