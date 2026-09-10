use ride_engine::CompletionResponse;

#[derive(serde::Serialize)]
pub struct QueryOut {
    pub query_id: u64,
    pub truncated: bool,
    pub site: String,
    pub replace_start_byte: u32,
    pub hits: Vec<HitOut>,
}

#[derive(serde::Serialize)]
pub struct HitOut {
    pub name: String,
    pub path: String,
    pub kind: String,
    pub crate_name: String,
    pub signature: String,
    pub doc: String,
    pub import_path: Option<String>,
    pub source_path: Option<String>,
    pub score: f32,
}

pub fn print(resp: &CompletionResponse) {
    let hits: Vec<HitOut> = resp
        .hits
        .iter()
        .map(|h| HitOut {
            name: h.name.clone(),
            path: h.path.clone(),
            kind: format!("{:?}", h.item_kind),
            crate_name: h.crate_name.clone(),
            signature: h.signature.clone(),
            doc: h.doc_first_sentence.clone(),
            import_path: h.import_path.clone(),
            source_path: h.source_path.clone(),
            score: h.score,
        })
        .collect();
    match serde_json::to_string(&QueryOut {
        query_id: resp.query_id,
        truncated: resp.truncated,
        site: format!("{:?}", resp.site),
        replace_start_byte: resp.replace_start_byte,
        hits,
    }) {
        Ok(s) => println!("{s}"),
        Err(e) => eprintln!("{e}"),
    }
}
