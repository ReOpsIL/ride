pub struct Order {
    pub id: u32,
    pub quantity: u32,
    pub unit_price: u32,
}

pub fn run() {
    let order = Order {
        id: 7,
        quantity: 3,
        unit_price: 250,
    };
    let receipt = checkout(&order);
    println!("stack: order {} costs {receipt}", order.id);
}

fn checkout(order: &Order) -> u32 {
    let subtotal = price(order);
    let total = apply_tax(subtotal);
    total
}

fn price(order: &Order) -> u32 {
    let base = order.quantity * order.unit_price;
    let reduced = discount(base, order.quantity);
    reduced
}

fn discount(amount: u32, quantity: u32) -> u32 {
    let percent = if quantity >= 3 { 10 } else { 0 };
    let reduced = amount - amount * percent / 100;
    reduced
}

fn apply_tax(amount: u32) -> u32 {
    let tax = amount / 5;
    amount + tax
}
