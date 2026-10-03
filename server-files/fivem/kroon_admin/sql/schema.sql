CREATE TABLE IF NOT EXISTS `kroon_admin_bans` (
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

CREATE TABLE IF NOT EXISTS `kroon_admin_warnings` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `player_name` VARCHAR(100) NOT NULL,
    `license` VARCHAR(80) NOT NULL,
    `reason` VARCHAR(240) NOT NULL,
    `admin` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_kroon_admin_warnings_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kroon_admin_logs` (
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
