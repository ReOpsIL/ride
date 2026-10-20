#![allow(clippy::let_and_return, clippy::useless_vec)]

mod data;
mod dispatch;
mod faults;
mod heartbeat;
mod loops;
mod recursion;
mod stack;
mod stepping;
mod threads;

type Scenario = (&'static str, fn());

const SCENARIOS: [Scenario; 9] = [
    ("stepping", stepping::run),
    ("stack", stack::run),
    ("recursion", recursion::run),
    ("loops", loops::run),
    ("data", data::run),
    ("dispatch", dispatch::run),
    ("threads", threads::run),
    ("faults", faults::run),
    ("heartbeat", heartbeat::run),
];

fn main() {
    let only = std::env::args().nth(1);
    for (name, scenario) in SCENARIOS {
        if only.as_deref().is_none_or(|wanted| wanted == name) {
            println!("== {name} ==");
            scenario();
        }
    }
    println!("== done ==");
}
