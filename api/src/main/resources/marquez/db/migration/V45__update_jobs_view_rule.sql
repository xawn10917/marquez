ALTER TABLE jobs DROP CONSTRAINT IF EXISTS jobs_namespace_uuid_name_key;
DROP INDEX IF EXISTS jobs_namespace_uuid_name_key;

DROP INDEX IF EXISTS jobs_namespace_uuid_name_parent;
ALTER TABLE jobs DROP CONSTRAINT IF EXISTS unique_jobs_namespace_uuid_name_parent;
DROP INDEX IF EXISTS unique_jobs_namespace_uuid_name_parent;

ALTER TABLE jobs ADD COLUMN parent_job_id_string varchar(36) DEFAULT '';
UPDATE jobs SET parent_job_id_string=parent_job_uuid::text WHERE parent_job_uuid IS NOT NULL;

CREATE UNIQUE INDEX unique_jobs_namespace_uuid_name_parent ON jobs (name, namespace_uuid, parent_job_id_string);
ALTER TABLE jobs ADD CONSTRAINT unique_jobs_namespace_uuid_name_parent UNIQUE USING INDEX unique_jobs_namespace_uuid_name_parent;

CREATE OR REPLACE VIEW jobs_view
AS
WITH RECURSIVE
    job_fqn AS (
        SELECT uuid, name, namespace_name, NULL::text AS parent_job_name, NULL::uuid AS parent_job_uuid
        FROM jobs
        WHERE parent_job_uuid IS NULL
        UNION
        SELECT j1.uuid,
               j2.name || '.' || j1.name AS name,
               j2.namespace_name AS namespace_name,
               j2.name AS parent_job_name,
               j1.parent_job_uuid
        FROM jobs j1
        INNER JOIN job_fqn j2 ON j2.uuid=j1.parent_job_uuid AND j2.uuid != j1.uuid
    )
SELECT f.uuid,
       f.name,
       f.namespace_name,
       j.name AS simple_name,
       j.parent_job_uuid,
       f.parent_job_name,
       j.type,
       j.created_at,
       j.updated_at,
       j.namespace_uuid,
       j.description,
       j.current_version_uuid,
       j.current_job_context_uuid,
       j.current_location,
       j.current_inputs,
       j.symlink_target_uuid
FROM job_fqn f, jobs j
WHERE j.uuid=f.uuid;