
-- Get post for curation

DROP procedure IF EXISTS `curate`;

CREATE PROCEDURE `curate`()
BEGIN
    
	DECLARE id INT;
        
	SELECT `posts_view`.`id` INTO id FROM `posts_view` WHERE `posts_view`.`state` = 0 ORDER BY `posts_view`.`timestamp` DESC LIMIT 1;
	
	UPDATE `posts` SET `posts`.`state` = 1 WHERE `posts`.`id` = id;
    
	SELECT * FROM `posts_view` WHERE `posts_view`.`id` = id;
	
END;

-- Get post for voting

DROP procedure IF EXISTS `upvote`;

CREATE PROCEDURE `upvote`()
BEGIN
    
	SELECT * FROM `posts_view` WHERE `posts_view`.`rate` > 0 AND `posts_view`.`voted` = 'false' ORDER BY `posts_view`.`timestamp` DESC LIMIT 1;
	
END;

-- Approve a posts

DROP procedure IF EXISTS `approve`;

CREATE PROCEDURE `approve`(
	IN author VARCHAR(45),
	IN title VARCHAR(512),
	IN url VARCHAR(512),
	IN curator VARCHAR(45),
	IN remarks VARCHAR(512),
	IN state INT,
	IN rate INT,
	IN action VARCHAR(45)
)
BEGIN
    
	DECLARE activity_id INT DEFAULT 0;
		
	UPDATE `posts` SET `posts`.`curator` = curator, `posts`.`remarks` = remarks, `posts`.`state` = state, `posts`.`rate` = rate, `posts`.`curate_time` = NOW() WHERE `posts`.`url` = url;
	
	INSERT IGNORE INTO `activity` (`author`, `type`, `link`, `comments`) VALUES (curator, action, url, title);
	
	IF action = 'approve' THEN
  
		INSERT IGNORE `users` (`account`, `score`, `posts`, `approved`) values ( author, rate, 1, 1)
			ON DUPLICATE KEY
				UPDATE `score`= VALUES(`score`) + rate, `posts` = VALUES(posts) + 1, `approved` = VALUES(`approved`) + 1;
	
		ELSE IF action = 're-approve' THEN
		
				SELECT `id` INTO activity_id FROM `activity` WHERE `activity`.`link` = url;
		
			IF activity_id > 0 THEN 
		
					UPDATE `users` SET `score` = VALUES(`score`) + rate , `rejected` = VALUES(`rejected`) - 1, `approved` = VALUES(`approved`) + 1 WHERE `account` = author;
		
				ELSE IF activity_id = 0 THEN
		
					INSERT IGNORE `users` (`account`, `score`, `posts`, `approved`) values ( author, rate, 1, 1)
						ON DUPLICATE KEY
							UPDATE `score`= VALUES(`score`) + rate, `posts` = VALUES(posts) + 1, `approved` = VALUES(`approved`) + 1;
						
				END IF;
			
			END IF;
		
		END IF;
	
	END IF;

END;


-- Reject a posts


DROP procedure IF EXISTS `reject`;

CREATE PROCEDURE `reject`(
	IN author VARCHAR(45),
	IN title VARCHAR(512),
	IN url VARCHAR(512),
	IN curator VARCHAR(45),
	IN remarks VARCHAR(512),
	IN state INT,
	IN action VARCHAR(45)
)
BEGIN
    
	DECLARE added_points INT DEFAULT 0;
		
	UPDATE `posts` SET `posts`.`curator` = curator, `posts`.`remarks` = remarks, `posts`.`state` = state, `posts`.`curate_time` = NOW() WHERE `posts`.`url` = url;
	
	INSERT IGNORE `activity` (`author`, `type`, `link`, `comments`) VALUES (curator, action, url, title);
	
	IF action = 'reject' THEN
  
		INSERT IGNORE `users` (`account`, `posts`, `rejected`) values ( author, 1, 1)
			ON DUPLICATE KEY
				UPDATE `posts` = VALUES(posts) + 1, `rejected` = VALUES(`rejected`) + 1;
	
		ELSE IF action = 're-reject' THEN
		
				SELECT `value` INTO added_points FROM `activity` WHERE `activity`.`link` = url;
		
			IF added_points > 0 THEN 
		
					UPDATE `users` SET `score` = VALUES(`score`) - added_points , `rejected` = VALUES(`rejected`) + 1, `approved` = VALUES(`approved`) - 1 WHERE `account` = author;
		
				ELSE IF added_points = 0 THEN
		
					INSERT IGNORE `users` (`account`, `posts`, `rejected`) values ( author, 1, 1)
						ON DUPLICATE KEY
							UPDATE `posts` = VALUES(posts) + 1, `rejected` = VALUES(`rejected`) + 1;
					
				END IF;
			
			END IF;
		
		END IF;
	
	END IF;

	
END;


-- new team

DROP procedure IF EXISTS `new_team`;

CREATE PROCEDURE `new_team`(
	IN account VARCHAR(45),
	IN author VARCHAR(45),
	IN email VARCHAR(512),
	IN role VARCHAR(45),
	IN tag VARCHAR(45),
	IN message VARCHAR(512),
	IN authority INT(11),
	IN token_hash VARCHAR(512)
)
BEGIN
        
	INSERT IGNORE INTO `team` (`account`, `email`, `role`, `tag`, `status`, `message`, `authority`, `token_hash`) VALUES(account, email, role, tag, "pending", message, authority, token_hash);
	
	INSERT IGNORE INTO `blacklist` (`account`, `type`, `reason`, `admitter`) VALUES(account, 'opt_out', 'is_team_member', author);
	
	INSERT IGNORE `activity` (`author`, `type`, `link`, `comments`) VALUES (author, 'add_team', CONCAT('/@', account), CONCAT('New user @', account, ' added to team as ', role, '!') );
	
END;



-- remove team

DROP procedure IF EXISTS `remove_team`;

CREATE PROCEDURE `remove_team`(
	IN account VARCHAR(45),
	IN author VARCHAR(45)
)
BEGIN
       
	UPDATE `team` SET `team`.`status` = 'inactive' WHERE `team`.`account` = account;
	
	DELETE FROM `blacklist` WHERE `account` = account;
	
	INSERT IGNORE `activity` (`author`, `type`, `link`, `comments`) VALUES (author, 'remove_team', CONCAT('/@', account), CONCAT('Former team user @', account, ' removed!'));
	
END;


-- get team admins

DROP procedure IF EXISTS `team_admins`;

CREATE PROCEDURE `team_admins`()
BEGIN
        
	SELECT * FROM `team_view` WHERE `team_view`.`role` = 'admin' AND `team_view`.`status` = 'active';
	
END;


-- get team mods

DROP procedure IF EXISTS `team_mods`;

CREATE PROCEDURE `team_mods`()
BEGIN
        
	SELECT * FROM `team_view` WHERE `team_view`.`role` = 'moderator' AND `team_view`.`status` = 'active';
	
END;


-- get team curators

DROP procedure IF EXISTS `team_curies`;

CREATE PROCEDURE `team_curies`()
BEGIN
        
	SELECT * FROM `team_view` WHERE `team_view`.`role` = 'curator' AND `team_view`.`status` = 'active';
	
END;


-- get pending team

DROP procedure IF EXISTS `team_pending`;

CREATE PROCEDURE `team_pending`()
BEGIN
        
	SELECT * FROM `team_view` WHERE `team_view`.`status` = 'pending';
	
END;


-- get inactive team

DROP procedure IF EXISTS `team_inactive`;

CREATE PROCEDURE `team_inactive`()
BEGIN
        
	SELECT * FROM `team_view` WHERE `team_view`.`status` = 'inactive';
	
END;


-- get team

DROP procedure IF EXISTS `get_team`;

CREATE PROCEDURE `get_team`(
	IN username_or_email VARCHAR(512)
)
BEGIN
    
	SELECT * FROM `team_view` WHERE `team_view`.`account` = username_or_email OR `team_view`.`email` = username_or_email;
	
END;



-- set password_hash

DROP procedure IF EXISTS `set_password_hash`;

CREATE PROCEDURE `set_password_hash`(
	IN account_or_email VARCHAR(45),
	IN password_hash VARCHAR(512)
)
BEGIN
    
	UPDATE `team` SET `team`.`password_hash` = password_hash WHERE `team`.`account`  = account_or_email OR `team`.`email`  = account_or_email;
	
END;


-- get token_hash

DROP procedure IF EXISTS `token_hash`;

CREATE PROCEDURE `token_hash`(
	IN username VARCHAR(45)
)
BEGIN
    
	SELECT `token_hash` FROM `team` WHERE `team`.`account` = username;
	
END;


-- activate team

DROP procedure IF EXISTS `activate_team`;

CREATE PROCEDURE `activate_team`(
	IN username VARCHAR(45)
)
BEGIN
    
	UPDATE `team` SET `team`.`status` = 'active', `team`.`token_hash` = '' WHERE `team`.`account` = username;
	
END;


-- get team password_hash

DROP procedure IF EXISTS `password_hash`;

CREATE PROCEDURE `password_hash`(
	IN email_or_account VARCHAR(512)
)
BEGIN
    
	SELECT `password_hash` FROM `team`
		WHERE (`team`.`email` = email_or_account OR `team`.`account` = email_or_account ) AND `team`.`status` != 'inactive';
	
END;


-- delete team token_hash

DROP procedure IF EXISTS `delete_token_hash`;

CREATE PROCEDURE `delete_token_hash`(
	IN username VARCHAR(45)
)
BEGIN
    
	UPDATE `team` SET `team`.`token_hash` = '' WHERE `team`.`account` = username;
	
END;


-- Get approved posts

DROP procedure IF EXISTS `approved`;

CREATE PROCEDURE `approved`()
BEGIN
        
	SELECT * FROM `posts_view` WHERE `posts_view`.`state` > 1 AND `posts_view`.`voted` = 'false' ORDER BY `posts_view`.`timestamp` DESC LIMIT 20;
	
END;


-- Get ignored posts

DROP procedure IF EXISTS `ignored`;

CREATE PROCEDURE `ignored`()
BEGIN
        
	SELECT * FROM `posts_view` WHERE `posts_view`.`state` = 1 AND HOUR(TIMEDIFF(NOW(), `posts_view`.`timestamp`))>24 ORDER BY `posts_view`.`timestamp` DESC LIMIT 20;
	
END;


-- Get lost posts

DROP procedure IF EXISTS `lost`;

CREATE PROCEDURE `lost`()
BEGIN
        
	SELECT * FROM `posts_view` WHERE `posts_view`.`state` = 0 AND HOUR(TIMEDIFF(NOW(), `posts_view`.`timestamp`))>24 ORDER BY `posts_view`.`timestamp` DESC LIMIT 20;
	
END;


-- Get rejected posts

DROP procedure IF EXISTS `rejected`;

CREATE PROCEDURE `rejected`()
BEGIN
        
	SELECT * FROM `posts_view` WHERE `posts_view`.`state` = -1 ORDER BY `posts_view`.`timestamp` DESC LIMIT 20;
	
END;




-- Get all activity

DROP procedure IF EXISTS `all_activity`;

CREATE PROCEDURE `all_activity`()
BEGIN
        
	SELECT * FROM `activity_view` ORDER BY `activity_view`.`time` DESC LIMIT 20;
	
END;


-- Get curation activity

DROP procedure IF EXISTS `curation_activity`;

CREATE PROCEDURE `curation_activity`()
BEGIN
        
	SELECT * FROM `activity_view` WHERE `activity_view`.`type` = 'approve' OR `activity_view`.`type` = 'reject' ORDER BY `activity_view`.`time` DESC LIMIT 20;
	
END;


-- Get re_curation activity

DROP procedure IF EXISTS `re_curation_activity`;

CREATE PROCEDURE `re_curation_activity`()
BEGIN
        
	SELECT * FROM `activity_view` WHERE `activity_view`.`type` = 're-approve' OR `activity_view`.`type` = 're-reject' ORDER BY `activity_view`.`time` DESC LIMIT 20;
	
END;



-- Get finance activity

DROP procedure IF EXISTS `finance_activity`;

CREATE PROCEDURE `finance_activity`()
BEGIN
        
	SELECT * FROM `activity_view` WHERE `activity_view`.`type` = 'add_sponsor' OR `activity_view`.`type` = 'remove_sponsor' ORDER BY `activity_view`.`time` DESC LIMIT 20;
	
END;



-- Get team activity

DROP procedure IF EXISTS `team_activity`;

CREATE PROCEDURE `team_activity`()
BEGIN
        
	SELECT * FROM `activity_view` WHERE `activity_view`.`type` = 'add_team' OR `activity_view`.`type` = 'remove_team' ORDER BY `activity_view`.`time` DESC LIMIT 20;
	
END;



-- Get discussions activity

DROP procedure IF EXISTS `discussions_activity`;

CREATE PROCEDURE `discussions_activity`()
BEGIN
        
	SELECT * FROM `activity_view` WHERE `activity_view`.`type` = 'discussions' ORDER BY `activity_view`.`time` DESC LIMIT 20;
	
END;





-- add to blacklist


DROP procedure IF EXISTS `add_to_blacklist`;

CREATE PROCEDURE `add_to_blacklist`(
	IN account VARCHAR(45),
	IN author VARCHAR(45),
	IN type VARCHAR(45),
	IN reason VARCHAR(512)
)
BEGIN
	
	INSERT IGNORE `blacklist` (`account`, `admitter`, `type`, `reason`) VALUES(account, author, type, reason)
	ON DUPLICATE KEY UPDATE `type` = VALUES(`type`), `admitter` = VALUES(`admitter`), `reason` = VALUES(`reason`);
	
	INSERT IGNORE `activity` (`author`, `type`, `link`, `comments`) VALUES (author, 'add_to_blacklist', CONCAT('/@', account), CONCAT('Added @', account, ' to blacklist!'));
	
END;



-- remove from blacklist


DROP procedure IF EXISTS `remove_from_blacklist`;

CREATE PROCEDURE `remove_from_blacklist`(
	IN account VARCHAR(45),
	IN author VARCHAR(45)
)
BEGIN
	
	DELETE FROM `blacklist` WHERE `account` = account;
	
	INSERT IGNORE `activity` (`author`, `type`, `link`, `comments`) VALUES (author, 'remove_from_blacklist', CONCAT('/@', account), CONCAT('Removed @', account, ' from blacklist!'));
	
END;




-- Get blacklist_reported

DROP procedure IF EXISTS `blacklist_reported`;

CREATE PROCEDURE `blacklist_reported`()
BEGIN
	
	SELECT * FROM `blacklist_view` WHERE `blacklist_view`.`type` = 'reported' ORDER BY `blacklist_view`.`date` DESC;
	
END;





-- Get blacklist_probation

DROP procedure IF EXISTS `blacklist_probation`;

CREATE PROCEDURE `blacklist_probation`()
BEGIN
		
	SELECT * FROM `blacklist_view` WHERE `blacklist_view`.`type` = 'probation' ORDER BY `blacklist_view`.`date` DESC;
	
END;





-- Get blacklist_banned

DROP procedure IF EXISTS `blacklist_banned`;

CREATE PROCEDURE `blacklist_banned`()
BEGIN
		
	SELECT * FROM `blacklist_view` WHERE `blacklist_view`.`type` = 'banned' ORDER BY `blacklist_view`.`date` DESC;
	
END;





-- Get blacklist_opt_out

DROP procedure IF EXISTS `blacklist_opt_out`;

CREATE PROCEDURE `blacklist_opt_out`()
BEGIN
		
	SELECT * FROM `blacklist_view` WHERE `blacklist_view`.`type` = 'opt_out' ORDER BY `blacklist_view`.`date` DESC;
	
END;




-- Get blacklist

DROP procedure IF EXISTS `get_blacklist`;

CREATE PROCEDURE `get_blacklist`(
	IN lmt INT(11)
)
BEGIN
		
	SELECT COUNT(`id`) AS user_count FROM `users_view`;
	SELECT COUNT(`id`) AS blacklist_count FROM `blacklist_view`;
	SELECT * FROM `blacklist_view` WHERE `blacklist_view`.`type` != 'opt_out' ORDER BY `blacklist_view`.`date` DESC LIMIT 20 OFFSET lmt;
	
END;




-- bot activity

DROP procedure IF EXISTS `bot_activity`;

CREATE PROCEDURE `bot_activity`(
	IN account VARCHAR(45),
	IN url VARCHAR(512),
	IN note VARCHAR(45),
	IN vote_amount DECIMAL(4,2),
	IN permlink VARCHAR(512),
	IN type VARCHAR(45)
)
BEGIN
        
	BEGIN
		INSERT IGNORE `bot_activity` (`account`, `url`, `note`, `vote_amount`, `type`)
			VALUES(account, url, note, vote_amount, type);
	END;
		
	BEGIN
		IF type = "curation" THEN
		
			UPDATE `posts` SET `posts`.`voted` = 'true', `posts`.`vote_amount` = vote_amount WHERE `posts`.`permlink` = permlink;
		
		END IF;
	END;
	
END;




-- Get team without curators

DROP procedure IF EXISTS `team_no_curator`;

CREATE PROCEDURE `team_no_curator`()
BEGIN
    
	SELECT `account` FROM `team_view` WHERE (`team_view`.`role` = 'admin' OR `team_view`.`role` = 'moderator') AND `team_view`.`status` = 'active';
	
END;





-- Get dashboard data

DROP procedure IF EXISTS `get_dashboard`;

CREATE PROCEDURE `get_dashboard`()
BEGIN
    
	SELECT `bot_account`, `community_rate`, `team_rate`, `project_rate`, `daily_curation` FROM `settings_view`;
	SELECT COUNT(`id`) AS total_posts FROM `posts_view` WHERE DATE(`timestamp`) = CURDATE();
	SELECT COUNT(`id`) AS voted_posts FROM `posts_view` WHERE `posts_view`.`voted` = 'true' AND DATE(`timestamp`) = CURDATE();
	SELECT COUNT(*) AS total_team FROM `team_view`;
	SELECT 0 AS total_sponsors;
	SELECT COUNT(DISTINCT `author`) AS total_members FROM `posts_view`;
	
END;





-- Get bot data

DROP procedure IF EXISTS `get_bot`;

CREATE PROCEDURE `get_bot`()
BEGIN
    
	SELECT `bot_account`, `community_rate`, `team_rate`, `project_rate`, `daily_curation` FROM `settings_view`;
	SELECT COUNT(`id`) AS total_posts FROM `posts_view` WHERE DATE(`timestamp`) = CURDATE();
	SELECT COUNT(`id`) AS voted_posts FROM `posts_view` WHERE `posts_view`.`voted` = 'true' AND DATE(`timestamp`) = CURDATE();
	
END;





-- Get vote settings

DROP procedure IF EXISTS `vote_settings`;

CREATE PROCEDURE `vote_settings`()
BEGIN
    
	SELECT
		`bot_account`,
		`community_rate`,
		`team_rate`,
		`project_rate`,
		`curator_rate`,
		`common_comment`,
		`bot_holiday`,
		`holiday_days`,
		`vote_interval_minutes`
	FROM
		`settings_view`;
	
END;







-- Get settings data

DROP procedure IF EXISTS `get_settings`;

CREATE PROCEDURE `get_settings`()
BEGIN
    
	SELECT
		`community_rate`,
		`team_rate`,
		`project_rate`,
		`curator_rate`,
		`common_comment`,
		`bot_holiday`,
		`holiday_days`,
		`daily_curation`,
		`vote_interval_minutes`
	FROM
		`settings_view`;
	
END;



