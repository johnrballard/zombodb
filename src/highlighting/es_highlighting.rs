use crate::executor_manager::get_executor_manager;
use crate::highlighting::es_highlighting::pg_catalog::*;
use crate::zdbquery::ZDBQuery;
use pgrx::*;
use serde::Serialize;
use serde_json::*;

#[pgrx::pg_schema]
mod pg_catalog {
    use pgrx::*;
    use serde::*;

    #[allow(non_camel_case_types)]
    #[derive(PostgresEnum, Serialize, Deserialize)]
    pub enum HighlightType {
        unified,
        plain,
        fvh,
    }

    #[allow(non_camel_case_types)]
    #[derive(PostgresEnum, Serialize, Deserialize)]
    pub enum FragmenterType {
        simple,
        span,
    }

    #[allow(non_camel_case_types)]
    #[derive(PostgresEnum, Serialize, Deserialize)]
    pub enum EncoderType {
        default,
        html,
    }

    #[allow(non_camel_case_types)]
    #[derive(PostgresEnum, Serialize, Deserialize)]
    pub enum BoundaryScannerType {
        chars,
        sentence,
        word,
    }
}

#[pg_extern(parallel_safe, immutable)]
fn highlight(
    highlight_type: default!(Option<HighlightType>, NULL),
    require_field_match: default!(Option<bool>, false),
    number_of_fragments: default!(Option<i32>, NULL),
    highlight_query: default!(Option<ZDBQuery>, NULL),
    pre_tags: default!(Option<Vec<Option<String>>>, NULL),
    post_tags: default!(Option<Vec<Option<String>>>, NULL),
    tags_schema: default!(Option<String>, NULL),
    no_match_size: default!(Option<i32>, NULL),
    fragmenter: default!(Option<FragmenterType>, NULL),
    fragment_size: default!(Option<i32>, NULL),
    fragment_offset: default!(Option<i32>, NULL),
    force_source: default!(Option<bool>, true),
    encoder: default!(Option<EncoderType>, NULL),
    boundary_scanner_locale: default!(Option<String>, NULL),
    boundary_scan_max: default!(Option<i32>, NULL),
    boundary_chars: default!(Option<String>, NULL),
    phrase_limit: default!(Option<i32>, NULL),
    matched_fields: default!(Option<bool>, NULL),
    order: default!(Option<String>, NULL),
) -> Json {
    #[derive(Serialize)]
    struct Highlight {
        #[serde(rename = "type")]
        #[serde(skip_serializing_if = "Option::is_none")]
        type_: Option<HighlightType>,
        #[serde(skip_serializing_if = "Option::is_none")]
        number_of_fragments: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        pre_tags: Option<Vec<Option<String>>>,
        #[serde(skip_serializing_if = "Option::is_none")]
        post_tags: Option<Vec<Option<String>>>,
        #[serde(skip_serializing_if = "Option::is_none")]
        tags_schema: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        require_field_match: Option<bool>,
        #[serde(skip_serializing_if = "Option::is_none")]
        highlight_query: Option<ZDBQuery>,
        #[serde(skip_serializing_if = "Option::is_none")]
        no_match_size: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        fragmenter: Option<FragmenterType>,
        #[serde(skip_serializing_if = "Option::is_none")]
        fragment_size: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        fragment_offset: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        force_source: Option<bool>,
        #[serde(skip_serializing_if = "Option::is_none")]
        encoder: Option<EncoderType>,
        #[serde(skip_serializing_if = "Option::is_none")]
        boundary_scanner_locale: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        boundary_scan_max: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        boundary_chars: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        phrase_limit: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        matched_fields: Option<bool>,
        #[serde(skip_serializing_if = "Option::is_none")]
        order: Option<String>,
    }

    let highlight = Highlight {
        type_: highlight_type,
        number_of_fragments,
        pre_tags,
        post_tags,
        tags_schema,
        require_field_match,
        highlight_query,
        no_match_size,
        fragmenter,
        fragment_size,
        fragment_offset,
        force_source,
        encoder,
        boundary_scanner_locale,
        boundary_scan_max,
        boundary_chars,
        phrase_limit,
        matched_fields,
        order,
    };

    Json(json!(highlight))
}

#[pg_extern(parallel_safe, immutable, name = "highlight", requires = [ highlighting::es_highlighting::highlight, ])]
fn highlight_field(
    ctid: pg_sys::ItemPointerData,
    field: &str,
    _highlight_definition: default!(Json, "zdb.highlight()"),
    fcinfo: pg_sys::FunctionCallInfo,
) -> Option<Vec<Option<&'static String>>> {
    let highlights = match get_executor_manager().peek_query_state() {
        Some((query_desc, query_state)) => {
            match query_state.lookup_index_for_first_field(*query_desc, fcinfo) {
                Some(heap_oid) => query_state.get_highlight(heap_oid, ctid, field),
                None => None,
            }
        }
        None => None,
    };

    match highlights {
        Some(vec) => {
            let mut result = Vec::new();
            for highlight in vec {
                result.push(Some(highlight))
            }
            Some(result)
        }
        None => None,
    }
}

#[pg_extern(parallel_safe, immutable, requires = [ highlighting::es_highlighting::highlight, ])]
fn highlight_all_fields(
    ctid: pg_sys::ItemPointerData,
    _highlight_definition: default!(Json, "zdb.highlight()"),
    fcinfo: pg_sys::FunctionCallInfo,
) -> Json {
    let highlights = match get_executor_manager().peek_query_state() {
        Some((query_desc, query_state)) => {
            match query_state.lookup_index_for_first_field(*query_desc, fcinfo) {
                Some(heap_oid) => query_state.get_highlights(heap_oid, ctid),
                None => None,
            }
        }
        None => None,
    };

    match highlights {
        Some(highlights) => Json(json!(highlights)),
        None => Json(json!(null)),
    }
}

#[pg_extern(parallel_safe, immutable, requires = [ highlighting::es_highlighting::highlight, ])]
fn want_highlight(
    mut query: ZDBQuery,
    field: String,
    highlight_definition: default!(Json, "zdb.highlight()"),
) -> ZDBQuery {
    let highlights = query.highlights();
    highlights.insert(field, highlight_definition.0);
    query
}
