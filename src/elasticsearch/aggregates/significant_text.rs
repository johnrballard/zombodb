use crate::elasticsearch::Elasticsearch;
use crate::utils::json_to_string;
use crate::zdbquery::ZDBQuery;
use pgrx::prelude::*;
use pgrx::*;
use serde::*;
use serde_json::*;

#[pg_extern(immutable, parallel_safe)]
fn significant_text(
    index: PgRelation,
    field: &str,
    query: ZDBQuery,
    size: default!(i32, 10),
    filter_duplicate_text: default!(Option<bool>, true),
) -> TableIterator<(
    name!(term, Option<String>),
    name!(doc_count, i64),
    name!(score, f64),
    name!(bg_count, i64),
)> {
    #[derive(Deserialize, Serialize)]
    struct BucketEntry {
        doc_count: i64,
        key: serde_json::Value,
        score: f64,
        bg_count: i64,
    }

    #[derive(Deserialize, Serialize)]
    struct SignificantTextAggData {
        buckets: Vec<BucketEntry>,
    }

    #[derive(Deserialize, Serialize)]
    struct SignificantKeywords {
        significant_keywords: SignificantTextAggData,
    }

    let (prepared_query, index) = query.prepare(&index, Some(field.into()));
    let elasticsearch = Elasticsearch::new(&index);
    let request = elasticsearch.aggregate::<SignificantKeywords>(
        Some(field.into()),
        true,
        prepared_query,
        json! {
            {
                "sampler" : {
                    "shard_size" : (2.0 * (size as f32 * 1.5 + 10.0)) as i32
                },
                "aggregations": {
                    "significant_keywords" : {
                        "significant_text" : {
                            "field": field,
                            "size": size,
                            "filter_duplicate_text": filter_duplicate_text
                        }
                    }
                }
            }
        },
    );

    let result = request
        .execute()
        .expect("failed to execute aggregate search");

    TableIterator::new(
        result
            .significant_keywords
            .buckets
            .into_iter()
            .map(|entry| {
                (
                    json_to_string(entry.key),
                    entry.doc_count,
                    entry.score,
                    entry.bg_count,
                )
            }),
    )
}
