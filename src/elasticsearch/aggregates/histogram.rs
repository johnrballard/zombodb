use crate::elasticsearch::Elasticsearch;
use crate::zdbquery::ZDBQuery;
use pgrx::prelude::*;
use pgrx::*;
use serde::*;
use serde_json::*;

#[pg_extern(immutable, parallel_safe)]
fn histogram(
    index: PgRelation,
    field: &str,
    query: ZDBQuery,
    interval: f64,
    min_doc_count: default!(i32, 0),
) -> TableIterator<(name!(term, AnyNumeric), name!(doc_count, i64))> {
    #[derive(Deserialize, Serialize)]
    struct BucketEntry {
        doc_count: i64,
        key: AnyNumeric,
    }

    #[derive(Deserialize, Serialize)]
    struct HistogramAggData {
        buckets: Vec<BucketEntry>,
    }

    let (prepared_query, index) = query.prepare(&index, Some(field.into()));
    let elasticsearch = Elasticsearch::new(&index);
    let request = elasticsearch.aggregate::<HistogramAggData>(
        Some(field.into()),
        true,
        prepared_query,
        json! {
            {
                "histogram": {
                    "field": field,
                    "interval": interval,
                    "min_doc_count": min_doc_count
                }
            }
        },
    );

    let result = request
        .execute()
        .expect("failed to execute aggregate search");

    TableIterator::new(
        result
            .buckets
            .into_iter()
            .map(|entry| (entry.key, entry.doc_count)),
    )
}
