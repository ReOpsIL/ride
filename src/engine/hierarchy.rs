use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::Arc;

use crate::ffi::{CalleeHit, ItemKind, OutlineItem, TypeHierarchy, TypeNode};
use crate::highlight::{subtypes, supertypes};

use super::headers::Header;
use super::reach::Reach;
use super::{Engine, header_hits, refs};

const TYPE_KINDS: &[ItemKind] = &[
    ItemKind::Struct,
    ItemKind::Enum,
    ItemKind::Union,
    ItemKind::Trait,
    ItemKind::Class,
    ItemKind::Type,
];

#[uniffi::export]
impl Engine {
    pub fn callees(&self, session_id: u64, cursor_byte: u32) -> Vec<CalleeHit> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .map(|s| s.callees(cursor_byte))
                    .unwrap_or_default()
            })
            .unwrap_or_default()
        }))
        .unwrap_or_default()
    }

    pub fn type_hierarchy(&self, session_id: u64, cursor_byte: u32) -> TypeHierarchy {
        catch_unwind(AssertUnwindSafe(|| {
            hierarchy(self, session_id, cursor_byte)
        }))
        .unwrap_or_else(|_| TypeHierarchy::empty())
    }
}

struct Ctx {
    name: String,
    outline: Vec<OutlineItem>,
    path: String,
    reach: Reach,
}

fn hierarchy(engine: &Engine, session_id: u64, cursor_byte: u32) -> TypeHierarchy {
    let Ok(Some(ctx)) = engine.read(|i| {
        let session = i.sessions.get(&session_id)?;
        Some(Ctx {
            name: refs::symbol_name(session, cursor_byte)?,
            outline: session.outline().to_vec(),
            path: session
                .path()
                .map(|p| p.display().to_string())
                .unwrap_or_default(),
            reach: Reach::take(i, session_id, session),
        })
    }) else {
        return TypeHierarchy::empty();
    };
    let scope = ctx.reach.scope().clone();
    let headers = ctx.reach.headers();
    let tables = header_hits::tables(&scope.types, headers);
    let supers = supertypes(&tables, &ctx.name);
    let subs = subtypes(&tables, &ctx.name);
    let out = TypeHierarchy {
        name: ctx.name.clone(),
        supertypes: nodes(&supers, &ctx, headers),
        subtypes: nodes(&subs, &ctx, headers),
    };
    ctx.reach.remember(engine);
    out
}

fn nodes(names: &[String], ctx: &Ctx, headers: &[Arc<Header>]) -> Vec<TypeNode> {
    names.iter().map(|n| node(n, ctx, headers)).collect()
}

fn node(name: &str, ctx: &Ctx, headers: &[Arc<Header>]) -> TypeNode {
    if let Some(item) = find(&ctx.outline, name) {
        return TypeNode {
            name: name.to_string(),
            kind: item.kind,
            path: ctx.path.clone(),
            byte_start: item.start_byte,
        };
    }
    for header in headers {
        if let Some(item) = find(&header.summary.outline, name) {
            return TypeNode {
                name: name.to_string(),
                kind: item.kind,
                path: header.path.display().to_string(),
                byte_start: item.start_byte,
            };
        }
    }
    TypeNode {
        name: name.to_string(),
        kind: ItemKind::Type,
        path: String::new(),
        byte_start: 0,
    }
}

fn find<'a>(outline: &'a [OutlineItem], name: &str) -> Option<&'a OutlineItem> {
    outline
        .iter()
        .find(|o| o.name == name && TYPE_KINDS.contains(&o.kind))
}
