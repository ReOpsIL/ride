use quick_xml::Reader;
use quick_xml::events::Event;

use crate::ffi::TestCase;

use super::tag::entity;

#[derive(Clone, Copy)]
enum Field {
    Name,
    Tags,
    File,
    Line,
}

#[derive(Default)]
struct Listing {
    cases: Vec<TestCase>,
    current: Option<TestCase>,
    field: Option<Field>,
    buffer: String,
}

pub fn list(text: &str) -> Vec<TestCase> {
    let mut reader = Reader::from_str(text);
    let mut listing = Listing::default();
    loop {
        match reader.read_event() {
            Ok(Event::Start(tag)) => listing.open(tag.name().as_ref()),
            Ok(Event::Text(text)) => listing.push(&text.xml_content().unwrap_or_default()),
            Ok(Event::GeneralRef(reference)) => listing.push(&entity(&reference)),
            Ok(Event::End(tag)) => listing.close(tag.name().as_ref()),
            Ok(Event::Eof) | Err(_) => break,
            Ok(_) => {}
        }
    }
    listing.finish();
    listing.cases
}

impl Listing {
    fn open(&mut self, name: &[u8]) {
        match name {
            b"TestCase" => self.begin(),
            b"Name" => self.begin_field(Field::Name),
            b"Tags" => self.begin_field(Field::Tags),
            b"File" => self.begin_field(Field::File),
            b"Line" => self.begin_field(Field::Line),
            _ => {}
        }
    }

    fn close(&mut self, name: &[u8]) {
        match name {
            b"TestCase" => self.finish(),
            b"Name" | b"Tags" | b"File" | b"Line" => self.end_field(),
            _ => {}
        }
    }

    fn push(&mut self, text: &str) {
        if self.field.is_some() {
            self.buffer.push_str(text);
        }
    }

    fn begin(&mut self) {
        self.finish();
        self.current = Some(TestCase {
            suite: None,
            name: String::new(),
            file: None,
            line: None,
        });
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
        let Some(case) = self.current.as_mut() else {
            return;
        };
        if text.is_empty() {
            return;
        }
        match field {
            Field::Name => case.name = text,
            Field::Tags => case.suite = Some(text),
            Field::File => case.file = Some(text),
            Field::Line => case.line = text.parse().ok(),
        }
    }

    fn finish(&mut self) {
        let Some(case) = self.current.take() else {
            return;
        };
        if case.name.is_empty() {
            return;
        }
        self.cases.push(case);
    }
}
