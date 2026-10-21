use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

#[derive(Debug, Clone, Copy)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Debug)]
pub struct Rect {
    pub origin: Point,
    pub size: Point,
    pub label: String,
}

#[derive(Debug)]
pub enum Shape {
    Empty,
    Circle { center: Point, radius: f64 },
    Polygon(Vec<Point>),
}

fn extent(shape: &Shape) -> f64 {
    match shape {
        Shape::Empty => 0.0,
        Shape::Circle { center, radius } => center.x.abs() + center.y.abs() + radius,
        Shape::Polygon(points) => points.iter().map(|p| p.x.abs() + p.y.abs()).sum(),
    }
}

fn corner(rect: &Rect) -> Point {
    Point {
        x: rect.origin.x + rect.size.x,
        y: rect.origin.y + rect.size.y,
    }
}

pub fn run() {
    let point = Point { x: 1.5, y: -2.0 };
    let rect = Rect {
        origin: point,
        size: Point { x: 4.0, y: 3.0 },
        label: String::from("window"),
    };
    let shapes = vec![
        Shape::Empty,
        Shape::Circle {
            center: point,
            radius: 2.5,
        },
        Shape::Polygon(vec![point, rect.size, Point { x: 0.0, y: 0.0 }]),
    ];
    let maybe_found: Option<&Shape> = shapes.get(1);
    let missing: Option<&Shape> = shapes.get(9);
    let fixed: [i32; 8] = [1, 1, 2, 3, 5, 8, 13, 21];
    let tuple = (42u8, 'λ', "slice");
    let large: Vec<u32> = (0..250).collect();
    let mut inventory = HashMap::new();
    inventory.insert("apples", 12);
    inventory.insert("pears", 3);
    let shared = Rc::new(RefCell::new(vec![String::from("first")]));
    let alias = Rc::clone(&shared);
    alias.borrow_mut().push(String::from("second"));
    let boxed: Box<Rect> = Box::new(Rect {
        origin: point,
        size: point,
        label: "boxed".into(),
    });
    let extents: Vec<f64> = shapes.iter().map(extent).collect();
    let far = corner(&rect);
    println!(
        "data: {} at {far:?}, extents {extents:?}, found {:?}, missing {}, fixed {}, tuple {:?}, large {}, inventory {}, shared {}, boxed {:?}",
        rect.label,
        maybe_found.is_some(),
        missing.is_none(),
        fixed.len(),
        tuple,
        large.len(),
        inventory.len(),
        shared.borrow().len(),
        boxed
    );
}
