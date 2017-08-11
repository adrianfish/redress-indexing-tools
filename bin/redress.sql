--
-- Container for the redress category names from the catalogue
--
CREATE TABLE category
(
	category_id serial not null,
	name varchar(255) not null,
	category_description text,
	list_order integer not null,
	primary key(category_id)
);

CREATE TABLE category_order
(
	category_id integer references category(category_id),
	list_order integer not null
);

CREATE UNIQUE INDEX category_list_order_index ON category_order
(
	category_id,
	list_order
);

CREATE UNIQUE INDEX category_name_index ON category
(
	name
);

--
-- Table for storing the catalogue hierarchy
--
CREATE TABLE category_hierarchy
(
    parent_category_id integer references category(category_id),
    child_category_id integer references category(category_id)
);

CREATE TABLE ims_difficulty_lookup
(
    ims_difficulty varchar(255) not null,
    primary key(ims_difficulty)
);

INSERT INTO ims_difficulty_lookup values('');
INSERT INTO ims_difficulty_lookup values('very easy');
INSERT INTO ims_difficulty_lookup values('easy');
INSERT INTO ims_difficulty_lookup values('medium');
INSERT INTO ims_difficulty_lookup values('difficult');
INSERT INTO ims_difficulty_lookup values('very difficult');

CREATE TABLE content
(
	content_id SERIAL,
	source varchar(9) not null, -- manual | havested
	identifier text not null,
	format varchar(255) not null,
	title varchar(255),
	subject text,
	description text,
	language varchar(255),
	creators text,
	publishers text,
	ims_difficulty varchar(255) references ims_difficulty_lookup(ims_difficulty),
	redress_difficulty float,
	date date DEFAULT now(),
	uploader text,
	checked smallint DEFAULT 0,
	primary key(content_id)
);

CREATE UNIQUE INDEX identifier_index ON content
(
	identifier
);

SELECT nextval('content_content_id_seq');

-- Lookup table. Each content item can be in multiple categories
--
CREATE TABLE content_category
(
    content_id integer references content(content_id),
    category_id integer references category(category_id)
);

CREATE UNIQUE INDEX content_category_index ON content_category
(
	content_id,
	category_id
);

CREATE VIEW content_category_view AS
	SELECT identifier,title,subject,content.description,format,language,redress_difficulty,name as category,source
		FROM content,content_category,category
		WHERE content.content_id = content_category.content_id
		AND content_category.category_id = category.category_id;

CREATE VIEW content_category_full_view AS
    SELECT content.content_id,
            content.identifier,
            content.title,
            content.subject,
            content.description,
            content.format,
            content."language",
            content.creators,
            content.publishers,
            content.ims_difficulty,
            content.redress_difficulty,
            category.name AS category,
            content.source,
            content.date,
            content.uploader
                FROM content,
                        content_category,
                        category
                        WHERE ((content.content_id = content_category.content_id) AND (content_category.category_id = category.category_id));

CREATE VIEW content_category_summary_unique_view AS
    SELECT DISTINCT ON (content.identifier) content.identifier,
        content.title,
        content.description,
        content.format,
        content.creators,
        content.publishers,
        content.redress_difficulty AS difficulty,
        category.name AS category,
        content.source,
        content.date
            FROM content,
                    content_category,
                    category
                    WHERE ((content.content_id = content_category.content_id) AND (content_category.category_id = category.category_id))
                        ORDER BY content.identifier;

CREATE VIEW content_category_summary_view AS
    SELECT content.identifier,
            content.title,
            content.description,
            content.format,
            content.creators,
            content.publishers,
            content.redress_difficulty AS difficulty,
            category.name AS category,
            content.source,
            content.date
                FROM content,
                        content_category,
                        category
                            WHERE ((content.content_id = content_category.content_id) AND (content_category.category_id = category.category_id));

--
-- Clean up the content_category, content_creator and
-- content_publisher lookup tables before deletion of a content
-- record.
--
CREATE FUNCTION delete_before_content_deletion() RETURNS trigger AS '
    BEGIN
        IF OLD.content_id IS NULL THEN
            RAISE EXCEPTION ''content_id cannot be null'';
        END IF;

		DELETE FROM content_category WHERE content_id = OLD.content_id;

        RETURN OLD;
    END;
' LANGUAGE plpgsql;

CREATE TRIGGER clean_before_content_deletion BEFORE DELETE ON content
    FOR EACH ROW EXECUTE PROCEDURE delete_before_content_deletion();

CREATE FUNCTION delete_before_category_deletion() RETURNS trigger AS '
    BEGIN
        IF OLD.category_id IS NULL THEN
            RAISE EXCEPTION ''category_id cannot be null'';
        END IF;

		DELETE FROM category_hierarchy WHERE parent_category_id = OLD.category_id;
		DELETE FROM category_hierarchy WHERE child_category_id = OLD.category_id;

        RETURN OLD;
    END;
' LANGUAGE plpgsql;

CREATE TRIGGER clean_before_category_deletion BEFORE DELETE ON category
    FOR EACH ROW EXECUTE PROCEDURE delete_before_category_deletion();

GRANT SELECT ON category to redressuser;
GRANT SELECT ON content_category_summary_view to redressuser;
GRANT SELECT ON content_category_summary_unique_view to redressuser;
GRANT SELECT ON content_category_full_view to redressuser;
