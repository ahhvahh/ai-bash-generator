CREATE SCHEMA IF NOT EXISTS capability_catalog;

CREATE TABLE IF NOT EXISTS capability_catalog.capability (
    id                  text PRIMARY KEY,
    version             integer NOT NULL DEFAULT 1,
    capability_type     text NOT NULL DEFAULT 'function',
    description         text NOT NULL,
    match_instruction   text NOT NULL,
    input_description   text NOT NULL DEFAULT '',
    output_description  text NOT NULL DEFAULT '',
    implementation      text NOT NULL DEFAULT '',
    dependencies        text NOT NULL DEFAULT '',
    platform            text NOT NULL DEFAULT 'debian-linux',
    risk_level          integer NOT NULL DEFAULT 0,
    checksum            text NOT NULL DEFAULT '',
    enabled             boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector(
            'simple',
            coalesce(id, '') || ' ' ||
            coalesce(description, '') || ' ' ||
            coalesce(match_instruction, '') || ' ' ||
            coalesce(input_description, '') || ' ' ||
            coalesce(output_description, '')
        )
    ) STORED
);

CREATE INDEX IF NOT EXISTS capability_search_vector_idx
    ON capability_catalog.capability
    USING GIN (search_vector);

CREATE TABLE IF NOT EXISTS capability_catalog.capability_usage (
    id                    bigserial PRIMARY KEY,
    capability_id         text NOT NULL REFERENCES capability_catalog.capability(id),
    request_id            text NOT NULL,
    used_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (capability_id, request_id)
);
