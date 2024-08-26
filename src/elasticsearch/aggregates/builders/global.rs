//! This Module is to build...
//! https://www.elastic.co/guide/en/elasticsearch/reference/7.9/search-aggregations-bucket-global-aggregation.html
//!
//! Returns JsonB that is a Filer ES Query

use crate::elasticsearch::aggregates::builders::make_children_map;
use pgrx::*;
use serde_json::*;

#[pg_extern(immutable, parallel_safe)]
fn global_agg(aggregate_name: &str, children: default!(Option<Vec<JsonB>>, NULL)) -> JsonB {
    JsonB(json! {
        {
            aggregate_name: {
                "global": {},
                "aggs": make_children_map(children)
            }
        }
    })
}
