mod cpp;

use crate::ffi::{GenKind, GenOption, ItemKind, OutlineItem};
use crate::highlight::{Member, TypeTable};

const CPP_KINDS: [GenKind; 5] = [
    GenKind::Constructor,
    GenKind::Getters,
    GenKind::Setters,
    GenKind::EqualityOps,
    GenKind::StreamInsert,
];

pub struct Field {
    pub name: String,
    pub type_name: String,
}

pub struct GenType {
    pub name: String,
    pub fields: Vec<Field>,
}

impl GenType {
    pub fn from_scope(name: &str, types: &TypeTable) -> Self {
        let fields = TypeTable::resolve(&[types], name)
            .into_iter()
            .filter(|m| m.item.kind == ItemKind::Field)
            .map(Field::from)
            .collect();
        Self {
            name: name.to_string(),
            fields,
        }
    }
}

impl From<Member> for Field {
    fn from(member: Member) -> Self {
        let type_name = member.type_name.clone().unwrap_or_else(|| {
            if member.detail.is_empty() {
                "auto".to_string()
            } else {
                member.detail.clone()
            }
        });
        Field {
            name: member.item.name,
            type_name,
        }
    }
}

pub fn enclosing_type(outline: &[OutlineItem], cursor: u32) -> Option<&OutlineItem> {
    outline
        .iter()
        .filter(|i| matches!(i.kind, ItemKind::Class | ItemKind::Struct | ItemKind::Union))
        .filter(|i| i.start_byte <= cursor && cursor <= i.end_byte)
        .min_by_key(|i| i.end_byte - i.start_byte)
}

pub fn options(t: &GenType) -> Vec<GenOption> {
    if t.fields.is_empty() {
        return Vec::new();
    }
    CPP_KINDS
        .iter()
        .map(|&kind| GenOption {
            kind,
            title: title(kind),
        })
        .collect()
}

pub fn apply(t: &GenType, kind: GenKind) -> String {
    match kind {
        GenKind::Constructor => cpp::constructor(t),
        GenKind::Getters => cpp::getters(t),
        GenKind::Setters => cpp::setters(t),
        GenKind::EqualityOps => cpp::equality(t),
        GenKind::StreamInsert => cpp::stream_insert(t),
    }
}

fn title(kind: GenKind) -> String {
    match kind {
        GenKind::Constructor => "Constructor",
        GenKind::Getters => "Getters",
        GenKind::Setters => "Setters",
        GenKind::EqualityOps => "Equality operators",
        GenKind::StreamInsert => "Stream operator",
    }
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::highlight::{BufferSession, Lang};

    fn gen_type(name: &str, src: &str) -> GenType {
        let (session, _) = BufferSession::open_lang(Lang::Cpp, src.to_string(), None).unwrap();
        let scope = session.scope();
        GenType::from_scope(name, &scope.types)
    }

    const RECT: &str =
        "using Real = double;\nclass Rect {\n    Real width_;\n    Real height_;\n};\n";

    #[test]
    fn fields_carry_declared_type() {
        let t = gen_type("Rect", RECT);
        let names: Vec<&str> = t.fields.iter().map(|f| f.name.as_str()).collect();
        assert_eq!(names, vec!["width_", "height_"]);
        assert!(t.fields.iter().all(|f| f.type_name == "Real"));
    }

    #[test]
    fn constructor_has_params_and_init_list() {
        let text = cpp::constructor(&gen_type("Rect", RECT));
        assert!(text.contains("Rect(Real width, Real height)"), "{text}");
        assert!(text.contains(": width_(width), height_(height)"), "{text}");
    }

    #[test]
    fn getters_one_per_field() {
        let text = cpp::getters(&gen_type("Rect", RECT));
        assert!(
            text.contains("Real width() const { return width_; }"),
            "{text}"
        );
        assert!(
            text.contains("Real height() const { return height_; }"),
            "{text}"
        );
    }

    #[test]
    fn setters_one_per_field() {
        let text = cpp::setters(&gen_type("Rect", RECT));
        assert!(
            text.contains("void set_width(Real value) { width_ = value; }"),
            "{text}"
        );
    }

    #[test]
    fn equality_pair() {
        let text = cpp::equality(&gen_type("Rect", RECT));
        assert!(
            text.contains("bool operator==(const Rect& other) const"),
            "{text}"
        );
        assert!(
            text.contains("width_ == other.width_ && height_ == other.height_"),
            "{text}"
        );
        assert!(
            text.contains("bool operator!=(const Rect& other) const"),
            "{text}"
        );
    }

    #[test]
    fn stream_insert_operator() {
        let text = cpp::stream_insert(&gen_type("Rect", RECT));
        assert!(
            text.contains("friend std::ostream& operator<<(std::ostream& os, const Rect& v)"),
            "{text}"
        );
        assert!(text.contains("v.width_ << \", \" << v.height_"), "{text}");
    }

    #[test]
    fn options_present_with_fields_absent_without() {
        assert_eq!(options(&gen_type("Rect", RECT)).len(), 5);
        assert!(options(&gen_type("Empty", "class Empty {};\n")).is_empty());
    }

    #[test]
    fn getter_prefixes_without_underscore() {
        let src = "class Point {\npublic:\n    int x;\n};\n";
        let text = cpp::getters(&gen_type("Point", src));
        assert!(text.contains("int get_x() const { return x; }"), "{text}");
    }
}
