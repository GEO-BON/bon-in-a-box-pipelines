_Auteurs: Maria Camila Diaz, Victor Julio Rincon, Laetitia Tremblay, Jory Griffith_

Statut de révision: En révision

## Présentation

Le Indice de la Liste rouge (RLI) montre l'évolution du risque global d'extinction pour les espèces et est utilisé pour suivre les progrès vers la réduction des extinctions et de la perte de biodiversité. De nombreuses espèces qui déplacent des catégories dans le Liste rouge le font en raison de la taxonomie révisée ou de l'amélioration des connaissances. Par conséquent, l'examen des tendances brutes du statut Liste rouge peut être trompeur. RLI modèles ces tendances pour montrer des changements globaux de la situation des groupes d'espèces qui sont basés uniquement sur une amélioration ou une dissuasion réelle.

RLI a été largement intégré dans divers cadres politiques. Initialement utilisée pour évaluer les progrès accomplis dans la réalisation de l'objectif de 2010 de la Convention sur la diversité biologique (Rodrigues, 2006), elle a depuis été utilisée dans les évaluations régionales, thématiques et mondiales par des organismes tels que la Plateforme intergouvernementale scientifique et politique sur la biodiversité et les services écosystémiques (IPBES), l'Avenir de l'environnement mondial et d'autres (Global Biodiversity Outlook, 2010).

### Utilisations

Le RLI est un indicateur clé des objectifs de développement durable de l'ONU, en particulier l'objectif 15, et il est adopté par la Convention sur les espèces migratrices et ses accords. Il sert également d'indicateur principal pour les objectifs A et 4 de la CDB, Cadre mondial de la biodiversité de Kunming-Montréal (CDB, 2022). De plus, en suivant la proportion d'espèces menacées qui montrent une amélioration du statut, le RLI joue un rôle central dans l'évaluation des progrès réalisés vers le but A. Au-delà des tendances mondiales, le RLI peut être utilisé pour suivre les changements dans le risque d'extinction dans les domaines biogéographiques, les unités politiques, les écosystèmes, les habitats, les groupes taxonomiques, les types de menaces, l'utilisation ou les métiers, ainsi que ceux pertinents aux divers accords et traités internationaux (Butchart et al., 2004; Butchart et al., 2005). Le RLI appuie les progrès accomplis vers la réalisation de plusieurs autres buts et cibles dans le cadre, comme le but B, la cible 2 et la cible 5, soulignant les changements dans le risque d'extinction, y compris pour les espèces utilisées. En calculant le RLI dans des contextes plus spécifiques, comme pour les espèces touchées par la pollution (cible 7), les espèces touchées par les espèces exotiques envahissantes (cible 6b) ou celles utilisées pour l'alimentation et la médecine (cible 9b), l'indicateur fournit des renseignements ciblés qui éclairent directement les efforts déployés pour atteindre ces objectifs. Pour en savoir plus sur l'indicateur RLI du Cadre mondial de la biodiversité, voir les métadonnées [ici](https://www.gbf-indicators.org/metadata/headline/A-3).

Les éléments suivants sont suggérés qui sont propres à chaque objectif :

RLI des espèces touchées par la pollution (cible 7)**

- Pays: Le choix de l'utilisateur
- Groupe taxonomique: Tous
- Catégorie de menace : Pollution
- Utilisation des espèces: Ne pas filtrer par l'utilisation ou le commerce des espèces

**2. RLI des espèces touchées par des espèces exotiques envahissantes (cible 6b)**

- Pays: Le choix de l'utilisateur
- Groupe taxonomique: Tous
- Catégorie de menace : Espèces ou maladies exotiques envahissantes
- Utilisation des espèces: Ne pas filtrer par l'utilisation ou le commerce des espèces

**3. RLI des espèces utilisées dans les aliments et les médicaments (cible 9b)**

- Pays: Le choix de l'utilisateur
- Groupe taxonomique: Tous
- Catégorie de menace : Ne pas filtrer par catégorie de menace
- Utilisation des espèces : aliments - humains, aliments - animaux, médicaments - humains et vétérinaires

RLI pour toutes les espèces utilisées (objectif B et cible 5)**

- Pays: Le choix de l'utilisateur
- Groupe taxonomique: Tous
- Catégorie de menace : Ne pas filtrer par catégorie de menace
- Utilisation des espèces : Toutes

RLI pour les espèces menacées par la pêche (cible 9)**
- Pays: Le choix de l'utilisateur
- Groupe taxonomique: Tous
- Catégorie de menace : Pêche
- Utilisation des espèces: Ne pas filtrer par l'utilisation ou le commerce des espèces

### Limites du pipeline

- Dans les grands pays ou les pays riches en espèces, ainsi que dans les catégories de menace ou d'utilisation qui comptent un nombre important d'espèces, ce pipeline prend beaucoup de temps pour récupérer les données.

- Ce pipeline calcule le RLI pour les espèces seulement. Les sous-espèces, sous-populations et variétés sont exclues de l'analyse.

- La liste des évaluations de l'UICN extraites pour ce pipeline ne sont que celles faites à l'échelle mondiale. Les évaluations régionales sont exclues de l'analyse.

## Avant de commencer

Pour utiliser ce pipeline, vous aurez besoin d'un [Jeton UICN](https://api.iucnredlist.org/users/sign_up) pour accéder aux données sur l'Union internationale pour la conservation de la nature (UICN) Liste rouge des espèces menacées.

Pour interpréter les résultats de ce pipeline, il est important de comprendre les catégorisations de menaces de l'UICN, qui sont présentes tout au long du sorties. Certains résultats présentent ces catégorisations directement, tandis que d'autres, comme les calculs Indice de la Liste rouge (RLI), les utilisent pour modéliser les changements dans le risque d'extinction au fil du temps. Le Liste rouge de l'UICN des espèces menacées définit les catégories de menaces suivantes :

- EX: Exinct
- EW: Éteint à l'état sauvage
- RE: Disparu au niveau régional
- CR: En danger critique
- EN: En danger
- VU: Vulnérable
- LR/cd: Risque faible - Dépendant de mesures de conservation
- NT or LR/nt: Quasi menacé
- LC or LR/lc: Préoccupation mineure
- DD: Données insuffisantes

(UICN, 2025)

## Exécution du pipeline


### Entrées du pipeline

Le pipeline BON in a Box RLI vous permet de calculer RLI pour les espèces d'un pays d'intérêt, filtrant par groupe taxonomique, type de menace et utilisation ou commerce d'espèces. Les intrants du pipeline sont :

- **Pays:** L'utilisateur doit choisir le pays pour lequel il veut calculer RLI.

- **Groupe taxonomique:** L'utilisateur peut spécifier le ou les groupes taxonomiques pour lesquels il veut calculer RLI à l'aide du menu déroulant. C'est un menu à choix multiples. Si 'All' est sélectionné, le pipeline comprendra tous les groupes de taxons.

- **Utilisation par espèces:** L'utilisateur peut spécifier quelles espèces utilisent ou négocient pour filtrer l'espèce. C'est un menu à choix multiples. Par exemple, si l'utilisateur choisit « Médicine - humaine & vétérinaire », le RLI sera calculé uniquement pour les espèces utilisées dans l'industrie médicale. L'utilisateur peut choisir d'omettre ce filtre en sélectionnant « Ne pas filtrer par l'utilisation ou le commerce d'espèces ». Si 'All' est sélectionné, le pipeline comprendra toutes les espèces utilisées.

- **Catégorie de menaces :** L'utilisateur peut spécifier par quelles espèces les menaces peuvent filtrer l'espèce. C'est un menu à choix multiples. Par exemple, si l'utilisateur choisit 'Pollution', le RLI ne sera calculé que pour les espèces menacées par la pollution. L'utilisateur peut choisir d'omettre ce filtre en sélectionnant « Ne pas filtrer par catégorie de menace ».

### Étapes du pipeline

#### **1. Obtenir une liste des espèces pour le pays d'intérêt**

Cette étape permet de récupérer la liste complète des espèces évaluées par le Liste rouge de l'UICN des espèces menacées pour le pays d'intérêt, y compris leur catégorisation la plus récente.

#### **2. Obtenir une liste des espèces pour le ou les groupes de taxons sélectionnés**

Cette étape permet de récupérer la liste complète des espèces évaluées par le Liste rouge de l'UICN des espèces menacées pour le groupe taxonomique sélectionné. Si 'All' est sélectionné pour le groupe taxonomique, cette étape retournera une liste vide afin qu'il n'y ait pas de filtre basé sur le groupe taxonomique.

#### **3. Obtenir une liste des espèces menacées par les types de menaces sélectionnés**

Cette étape permet de retrouver la liste complète des espèces évaluées par le Liste rouge de l'UICN des espèces menacées qui sont menacées par le type de menace sélectionné. Si 'Ne pas filtrer par catégorie de menace' est sélectionné pour la catégorie de menace, cette étape retournera une liste vide afin qu'il n'y ait pas de filtre basé sur le type de menace.

#### **4. Obtenir une liste des espèces pour l'utilisation ou les échanges sélectionnés**

Cette étape permet de récupérer la liste complète des espèces évaluées par le Liste rouge de l'UICN des espèces menacées qui sont impliquées dans l'utilisation ou les échanges sélectionnés. Si 'Ne pas filtrer par l'utilisation ou le commerce d'espèces' est choisi pour l'utilisation d'espèces, cette étape retournera une liste vide afin qu'il n'y ait pas de filtre basé sur l'utilisation ou le commerce. Si 'All' est choisi pour l'utilisation d'espèces, cette étape permettra de retourner toutes les espèces impliquées dans une utilisation ou un commerce, également appelées espèces *utilisées*.

#### **5. Combiner les listes des étapes précédentes en une seule liste**

Cette étape prend la liste des espèces pour le pays d'intérêt et filtre les espèces qui ne figurent dans aucune des listes des étapes 2, 3 et 4.

#### **6. Évaluation de l'historique de l'espèce**

Cette étape renvoie l'historique des évaluations (année et statut d'évaluation) pour chaque espèce de la liste à partir de l'étape 5.

#### **7. Calcul du Indice de la Liste rouge**

Cette étape calcule le Indice de la Liste rouge pour l'espèce en utilisant son historique d'évaluations. La plupart des espèces se déplacent d'une catégorie à l'autre du Liste rouge de l'UICN en raison de l'amélioration des connaissances ou de la nouvelle taxonomie, de sorte qu'examiner le nombre d'espèces dans chaque catégorie au fil du temps n'est pas une mesure significative des changements globaux dans le risque d'extinction. Le RLI a été conçu pour refléter une amélioration ou une détérioration réelle de la situation des espèces individuelles (Butchart et al., 2004; Butchart et al., 2005), et il est calculé en fonction de la proportion d'espèces dans chaque catégorie sur le Liste rouge (Préoccupation mineure, Vulnérable, En danger, etc.) et pondéré par la proportion de la zone qui se trouve dans le pays ou la région d'intérêt. RLI peut être calculé pour toutes les espèces d'une région donnée, ou séparément pour des taxons spécifiques (p. ex. oiseaux) ou d'autres groupes spécifiés (p. ex. espèces endémiques). Les valeurs de RLI varient entre 0 (indiquer que toutes les espèces sont éteintes) et 1 (indiquer que toutes les espèces sont Préoccupation mineure). Pour plus d'informations sur le RLI, visitez le [Site de l'UICN](https://www.iucnredlist.org/).

### Sorties du pipeline

- **Liste rouge données:** Un ensemble de données décrivant les résultats du calcul RLI.

- **Liste rouge tendance graphique :** Le Indice de la Liste rouge des espèces pour le groupe taxonomique choisi au fil du temps. Un RLI de 1 indique que toutes les espèces ont un statut de moins concerné, alors que 0 indique qu'elles ont disparu. Si la valeur RLI est constante au fil du temps, le risque global d'extinction demeure inchangé. Une tendance à la hausse montre une réduction du taux de perte de biodiversité.

- **Matrice Liste rouge:** Une matrice des catégories de menaces de toutes les espèces d'intérêt au fil du temps.

- **Nombre d'espèces:** Le nombre d'espèces pour le pays d'intérêt, filtré par le taxon, la menace et les catégories d'utilisation.

- **Pays:** Le pays d'origine de la liste des espèces.

- **Groupe(s) taxonomique(s):** Le ou les groupes taxonomiques des espèces évaluées.

- **Menaces pour l'espèce :** Les menaces auxquelles sont exposées les espèces évaluées.

- **Utilisation(s) des espèces:** L'utilisation ou le commerce des espèces évaluées.

- **Citation de l'API de l'IUCN :** Citation pour les données acquises à l'aide de l'API Liste rouge de l'UICN.

## Exemple

**Exemple d'exécution:** Voir un exemple d'exécution RLI ici dans les [Interface d'exécution](https://pipelines-results.geobon.org/pipeline-form/_2025-10-16%3ERLI_pipeline%3EIUCN_RLI_pipeline/40d810fb1dd12ea71f08381383a0686a) et [Visualiseur](https://pipelines-results.geobon.org/viewer/_2025-10-16%3ERLI_pipeline%3EIUCN_RLI_pipeline%3E40d810fb1dd12ea71f08381383a0686a).

## Dépannage

**Erreurs communes:**

- `HTTP 404 Not Found` : cette erreur indique un défaut de connexion à l'API Liste rouge de l'UICN. C'est généralement parce que le jeton UICN fourni n'est pas valide.

## Références

Butchart SHM, Stattersfield AJ, Bennun LA, Shutes SM, Akçakaya HR, et al. 2004. Measuring global trends in the status of biodiversity: Red List Indices for birds. PLoS Biology 2: e383.

Butchart SHM, Stattersfield AJ, Baillie JEM, Bennun LA, Stuart SN, et al. 2005. Using Red List Indices to measure progress towards the 2010 target andbeyond. Philosophical Transactions of the Royal Society of London B 360: 255–268.

Butchart SH, Resit Akçakaya H, Chanson J, Baillie JE, Collen B, et al. 2007. Improvements to the Red List Index. PLOS ONE 2(1): e140.
Cardoso, P., Branco, V. 2023. IUCN Redlisting Tools (Package red).

CBD 2022. Proposed monitoring framework for the post-2020 global biodiversity framework. CBD: Convention on Biological Diversity.
Global Biodiversity Outlook. 2010. Global biodiversity outlook 3. In Montréal, Canada: Secretariat of the Convention on Biological Diversity.(http://gbo3.cbd.int/) Phil. Trans. R. Soc. B (Vol. 9).
Rodrigues ASL, Pilgrim JD, Lamoreux JF, Hoffmann M, Brooks TM.2006. The value of the IUCN Red List for Conservation. Trends in Ecology & Evolution 21: 71–76.

IUCN. 2025. The IUCN Red List of Threatened Species. Version 2025-1. https://www.iucnredlist.org.


