CREATE DATABASE IF NOT EXISTS app;
USE app;
DROP PROCEDURE IF EXISTS init;
DELIMITER //
CREATE PROCEDURE init ()
LANGUAGE SQL
BEGIN
  DECLARE data_present INT;
  CREATE TABLE IF NOT EXISTS fruits (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64),
    value INT
  );
  SET data_present = (SELECT COUNT(*) FROM fruits);
  IF data_present = 0 THEN
    INSERT INTO fruits (name, value) VALUES
      ('apples', 10),
      ('oranges', 20),
      ('bananas', 15),
      ('lemons', 5),
      ('pears', 3),
      ('apricots', 7),
      ('kiwis', 9),
      ('mangos', 12),
      ('figs', 4),
      ('limes', 8);
  END IF;
END;//
DELIMITER ;
CALL init();
