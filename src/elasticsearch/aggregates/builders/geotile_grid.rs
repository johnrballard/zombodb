//! This Module is to build...
//! https://www.elastic.co/guide/en/elasticsearch/reference/7.9/search-aggregations-bucket-daterange-aggregation.html
//!
//! Returns JsonB that is a Filer ES Query

use pgrx::*;
use serde::*;
use serde_json::*;

#[derive(Serialize)]
struct GeogridGrid<'a> {
    field: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    precision: Option<i16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    bounds: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    size: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    shard_size: Option<i64>,
}

#[pg_extern(immutable, parallel_safe)]
fn geogrid_grid_agg(
    aggregate_name: &str,
    field: &str,
    precision: default!(Option<i16>, NULL),
    bounds: default!(Option<&str>, NULL),
    size: default!(Option<i64>, NULL),
    shard_size: default!(Option<i64>, NULL),
) -> JsonB {
    let geogrid_grid = GeogridGrid {
        field,
        precision,
        bounds,
        size,
        shard_size,
    };
    JsonB(json! {
        {
            aggregate_name: {
                "geogrid_grid":
                    geogrid_grid
            }
        }
    })
}
