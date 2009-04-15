CREATE TABLE list (
  id             INTEGER PRIMARY KEY,
  name           CHAR(64) NOT NULL
);

CREATE TABLE migrate_version (
   version INTEGER DEFAULT 0
);
