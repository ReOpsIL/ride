use tree_sitter::{InputEdit, Parser, Point};

use crate::error::EngineError;
use crate::ffi::InputEditFfi;

pub fn rust_parser() -> Result<Parser, EngineError> {
    let mut parser = Parser::new();
    parser
        .set_language(&tree_sitter_rust::LANGUAGE.into())
        .map_err(|e| EngineError::InvalidEdit {
            message: format!("{e:?}"),
        })?;
    Ok(parser)
}

pub fn apply_replica(
    replica: &mut String,
    edit: &InputEditFfi,
    inserted: &str,
) -> Result<(), EngineError> {
    let start = edit.start_byte as usize;
    let old_end = edit.old_end_byte as usize;
    if start > replica.len() || old_end > replica.len() || start > old_end {
        return Err(EngineError::InvalidEdit {
            message: "byte range out of bounds".into(),
        });
    }
    if !replica.is_char_boundary(start) || !replica.is_char_boundary(old_end) {
        return Err(EngineError::InvalidEdit {
            message: "edit not on utf-8 boundary".into(),
        });
    }
    replica.replace_range(start..old_end, inserted);
    Ok(())
}

pub fn to_ts_edit(edit: &InputEditFfi) -> InputEdit {
    InputEdit {
        start_byte: edit.start_byte as usize,
        old_end_byte: edit.old_end_byte as usize,
        new_end_byte: edit.new_end_byte as usize,
        start_position: Point {
            row: edit.start_row as usize,
            column: edit.start_column as usize,
        },
        old_end_position: Point {
            row: edit.old_end_row as usize,
            column: edit.old_end_column as usize,
        },
        new_end_position: Point {
            row: edit.new_end_row as usize,
            column: edit.new_end_column as usize,
        },
    }
}
