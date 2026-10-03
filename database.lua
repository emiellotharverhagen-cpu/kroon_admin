local function initializeDatabase()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `license` VARCHAR(80) NOT NULL,
            `reason` VARCHAR(240) NOT NULL,
            `admin` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_kroon_admin_bans_license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Tables.bans))

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `player_name` VARCHAR(100) NOT NULL,
            `license` VARCHAR(80) NOT NULL,
            `reason` VARCHAR(240) NOT NULL,
            `admin` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_kroon_admin_warnings_license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Tables.warnings))

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `admin_name` VARCHAR(100) NOT NULL,
            `admin_license` VARCHAR(80) NULL,
            `action` VARCHAR(50) NOT NULL,
            `target_name` VARCHAR(100) NULL,
            `target_license` VARCHAR(80) NULL,
            `details` TEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_kroon_admin_logs_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Tables.logs))
end

CreateThread(function()
    local ok, err = pcall(initializeDatabase)
    if not ok then
        print(('[kroon_admin] Database initialisatie mislukt: %s'):format(err))
    else
        print('[kroon_admin] Database is gereed.')
    end
end)
