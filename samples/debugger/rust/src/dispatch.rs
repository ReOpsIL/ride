trait Area {
    fn name(&self) -> &str;
    fn area(&self) -> f64;
}

struct Circle {
    radius: f64,
}

struct Square {
    side: f64,
}

impl Area for Circle {
    fn name(&self) -> &str {
        "circle"
    }

    fn area(&self) -> f64 {
        let r = self.radius;
        std::f64::consts::PI * r * r
    }
}

impl Area for Square {
    fn name(&self) -> &str {
        "square"
    }

    fn area(&self) -> f64 {
        let s = self.side;
        s * s
    }
}

fn apply(op: fn(i32) -> i32, value: i32) -> i32 {
    op(value)
}

fn negate(value: i32) -> i32 {
    -value
}

pub fn run() {
    let shapes: Vec<Box<dyn Area>> = vec![
        Box::new(Circle { radius: 1.0 }),
        Box::new(Square { side: 2.0 }),
    ];
    let mut total = 0.0;
    for shape in &shapes {
        let area = shape.area();
        println!("dispatch: {} has area {area:.2}", shape.name());
        total += area;
    }
    let factor = 3;
    let scale = |value: i32| {
        let scaled = value * factor;
        scaled + 1
    };
    let scaled = scale(5);
    let negated = apply(negate, scaled);
    let mut words = vec!["pear", "fig", "banana"];
    words.sort_by_key(|word| word.len());
    println!("dispatch: total={total:.2} scaled={scaled} negated={negated} words={words:?}");
}
