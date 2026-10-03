# Kroon Admin serverbestanden

Deze map wordt gegenereerd met `npm run build:server-package`. Inhoud:

- `fivem/kroon_admin/`: complete FiveM-resource. Upload deze map als resource-map naar de `resources`-map van je game server.
- `web-panel/upload-to-document-root/`: alleen de PHP-panelbestanden die naar de document root van je domein moeten.
- `web-panel/database/schema.sql`: importeer dit schema in de MySQL-database op je webhosting.
- `web-panel/private/config.example.php`: veilig voorbeeld voor de PHP-configuratie. Kopieer/configureer deze buiten de document root; zet echte inloggegevens er niet in en upload het voorbeeld niet naar de document root.
- `web-panel/tools/`: PHP CLI-hulpmiddelen om een staffwachtwoord-hash te maken en een staffaccount aan te maken.
- `web-panel/README.md`: installatie- en verbindingsinstructies.

De game-serverdatabase is niet dezelfde database als de paneldatabase. De SQL onder `fivem/kroon_admin/sql/` hoort bij oxmysql; `web-panel/database/schema.sql` hoort bij de hostingdatabase.
