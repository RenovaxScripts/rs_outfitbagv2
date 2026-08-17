CREATE TABLE IF NOT EXISTS `rs_multijob_jobs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(128) NOT NULL,
    `job_name` VARCHAR(64) NOT NULL,
    `job_label` VARCHAR(128) NOT NULL,
    `grade` INT NOT NULL DEFAULT 0,
    `grade_label` VARCHAR(128) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier_job` (`identifier`, `job_name`),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
