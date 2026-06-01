# Using as a git submodule in Serveaso-BE

```bash
# From Serveaso-BE root (after removing a copied database/ folder if needed):
git submodule add https://github.com/ServEase-Innovations/DB_Migrations.git database
git submodule update --init --recursive
cd database && npm install
```

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/ServEase-Innovations/Serveaso-BE.git
```

Update submodule pointer:

```bash
cd database && git pull origin main && cd ..
git add database && git commit -m "chore: bump DB_Migrations"
```
