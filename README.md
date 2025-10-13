# SAE5.01DevAvance
Dépôt du projet de la SAE 5.01 de Développement avancé | Développement d'une application de reconnaissance et de classement d'objets du monde réel en temps réel - Sujet choisi : Matériel scolaire
Membres : CHOLLET Thomas/AIT BAHA Said/MORINON Lilian/KERBER Alexandre

# 📘 Fiche Git – Organisation du projet SAE5.01DevAvance

## 👥 Équipe
| Membre | Branche personnelle |
|:--------|:--------------------|
| **Membre 1** | `membre1_branch` |
| **Membre 2** | `membre2_branch` |
| **Membre 3** | `membre3_branch` |
| **Membre 4** | `membre4_branch` |

> 💡 Chaque membre crée sa propre branche pour travailler sur sa partie sans modifier le code principal (`main`).

---

## ⚙️ Étapes pour travailler et pousser son code

### 🧭 1️⃣ Mettre à jour le projet avant de commencer
Toujours commencer par récupérer la dernière version du code commun :
```bash
git checkout main
git pull
```

---

### 🌱 2️⃣ Créer ou se placer sur sa branche personnelle
Si c’est la **première fois** que vous créez votre branche :
```bash
git checkout -b membreX_branch
```

Si la branche existe déjà :
```bash
git checkout membreX_branch
```

---

### 💾 3️⃣ Ajouter et enregistrer vos modifications
Quand vous avez fait des changements :
```bash
git add .
git commit -m "Description courte de ce qui a été fait"
```

Exemples :
- "Ajout de la page d'accueil Flutter"
- "Création du script d'entraînement TensorFlow"
- "Mise à jour du README"

---

### ☁️ 4️⃣ Envoyer (push) vos changements sur GitHub
Si c’est la **première fois** que vous poussez votre branche :
```bash
git push --set-upstream origin membreX_branch
```

Pour les fois suivantes :
```bash
git push
```

---

### 🔄 5️⃣ Mettre à jour votre branche avec les derniers changements de `main`
Quand quelqu’un a modifié `main`, synchronisez avant de continuer :
```bash
git checkout main
git pull
git checkout membreX_branch
git merge main
```

➡️ Cela intègre les nouveautés sans écraser votre travail.

---

### 🧩 6️⃣ Quand une partie est terminée
Quand votre partie est prête :
- Créez une **Pull Request** sur GitHub vers `main`,  
  *ou*
- Demandez à un membre de faire le merge localement :
```bash
git checkout main
git pull
git merge membreX_branch
git push
```

---

## 🧠 Récapitulatif rapide

| Action | Commande |
|--------|-----------|
| 🆕 Mettre à jour le projet | `git pull` |
| 🌿 Créer une branche perso | `git checkout -b nom_branche` |
| 🔁 Changer de branche | `git checkout nom_branche` |
| 💾 Sauvegarder les changements | `git add . && git commit -m "message"` |
| ☁️ Envoyer sur GitHub | `git push` |
| 🔄 Fusionner avec main | `git merge main` |

---

> ✨ **Conseil d’équipe :**
> - Travaillez chacun sur votre branche.  
> - Faites un `git pull` avant chaque session de code.  
> - Poussez vos changements régulièrement (petits commits fréquents > gros commits rares).  
> - Utilisez les *Pull Requests* GitHub pour valider avant de fusionner dans `main`.
