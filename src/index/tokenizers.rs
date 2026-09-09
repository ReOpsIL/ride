use tantivy::Index;
use tantivy::tokenizer::{LowerCaser, NgramTokenizer, TextAnalyzer};

use super::schema::{MAX_GRAM, PREFIX_TOKENIZER};

pub fn register(index: &Index) -> tantivy::Result<()> {
    let ngram = NgramTokenizer::prefix_only(1, MAX_GRAM)?;
    let analyzer = TextAnalyzer::builder(ngram).filter(LowerCaser).build();
    index.tokenizers().register(PREFIX_TOKENIZER, analyzer);
    Ok(())
}
