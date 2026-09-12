use quick_xml::Reader;
use quick_xml::events::{BytesStart, Event};

use crate::ffi::{TestEvent, TestStatus};
use crate::run::tests::event;

use super::tag::{attr, entity, location, status};

#[derive(Clone, Copy)]
enum Field {
    Original,
    Expanded,
    Skip,
}

#[derive(Default)]
struct Expression {
    location: String,
    kind: String,
    original: String,
    expanded: String,
}

#[derive(Default)]
struct Run {
    events: Vec<TestEvent>,
    current: Option<TestEvent>,
    lines: Vec<String>,
    sections: Vec<String>,
    expression: Option<Expression>,
    field: Option<Field>,
    buffer: String,
}

pub fn parse(text: &str) -> Vec<TestEvent> {
    let mut reader = Reader::from_str(text);
    let mut run = Run::default();
    loop {
        match reader.read_event() {
            Ok(Event::Start(tag)) => run.open(&tag),
            Ok(Event::Empty(tag)) => run.empty(&tag),
            Ok(Event::Text(text)) => run.push(&text.xml_content().unwrap_or_default()),
            Ok(Event::GeneralRef(reference)) => run.push(&entity(&reference)),
            Ok(Event::End(tag)) => run.close(tag.name().as_ref()),
            Ok(Event::Eof) | Err(_) => break,
            Ok(_) => {}
        }
    }
    run.events
}

impl Run {
    fn open(&mut self, tag: &BytesStart) {
        match tag.name().as_ref() {
            b"TestCase" => self.begin(tag),
            b"Section" => self.sections.push(attr(tag, "name").unwrap_or_default()),
            b"Expression" => self.begin_expression(tag),
            b"Original" => self.begin_field(Field::Original),
            b"Expanded" => self.begin_field(Field::Expanded),
            b"Skip" => self.begin_field(Field::Skip),
            _ => {}
        }
    }

    fn empty(&mut self, tag: &BytesStart) {
        if tag.name().as_ref() == b"OverallResult"
            && let Some(current) = self.current.as_mut()
        {
            current.status = status(tag);
        }
    }

    fn close(&mut self, name: &[u8]) {
        match name {
            b"TestCase" => self.finish(),
            b"Section" => {
                self.sections.pop();
            }
            b"Expression" => self.finish_expression(),
            b"Original" | b"Expanded" | b"Skip" => self.end_field(),
            _ => {}
        }
    }

    fn push(&mut self, text: &str) {
        if self.field.is_some() {
            self.buffer.push_str(text);
        }
    }

    fn begin_field(&mut self, field: Field) {
        self.field = Some(field);
        self.buffer.clear();
    }

    fn end_field(&mut self) {
        let Some(field) = self.field.take() else {
            return;
        };
        let text = self.buffer.trim().to_string();
        self.buffer.clear();
        if text.is_empty() {
            return;
        }
        if let Field::Skip = field {
            self.lines.push(text);
            return;
        }
        let Some(expression) = self.expression.as_mut() else {
            return;
        };
        match field {
            Field::Original => expression.original = text,
            Field::Expanded => expression.expanded = text,
            Field::Skip => {}
        }
    }

    fn begin(&mut self, tag: &BytesStart) {
        self.finish();
        let name = attr(tag, "name").unwrap_or_default();
        self.current = Some(event(attr(tag, "tags"), &name, TestStatus::Failed, None));
        self.lines.clear();
        self.sections.clear();
    }

    fn begin_expression(&mut self, tag: &BytesStart) {
        if attr(tag, "success").as_deref() == Some("true") {
            return;
        }
        self.expression = Some(Expression {
            location: location(tag),
            kind: attr(tag, "type").unwrap_or_default(),
            ..Expression::default()
        });
    }

    fn finish_expression(&mut self) {
        let Some(expression) = self.expression.take() else {
            return;
        };
        let mut head = String::new();
        if !self.sections.is_empty() {
            head = format!("{}: ", self.sections.join(" / "));
        }
        self.lines.push(format!(
            "{head}{}: {}({})",
            expression.location, expression.kind, expression.original
        ));
        if !expression.expanded.is_empty() {
            self.lines
                .push(format!("with expansion: {}", expression.expanded));
        }
    }

    fn finish(&mut self) {
        let Some(mut current) = self.current.take() else {
            return;
        };
        current.output = self.lines.join("\n");
        self.lines.clear();
        self.events.push(current);
    }
}
