#![allow(dead_code)]

use std::process::Command;
use std::sync::Mutex;
use std::thread::sleep;
use std::time::{Duration, Instant};

use ride_engine::{Breakpoint, DebugEvent, DebugListener};

#[derive(Default)]
pub struct Recorder {
    events: Mutex<Vec<DebugEvent>>,
    output: Mutex<Vec<String>>,
}

impl DebugListener for Recorder {
    fn on_event(&self, event: DebugEvent) {
        self.events.lock().unwrap().push(event);
    }

    fn on_output(&self, category: String, text: String) {
        self.output
            .lock()
            .unwrap()
            .push(format!("{category}: {text}"));
    }
}

impl Recorder {
    pub fn events(&self) -> Vec<DebugEvent> {
        self.events.lock().unwrap().clone()
    }

    pub fn output(&self) -> Vec<String> {
        self.output.lock().unwrap().clone()
    }

    pub fn saw(&self, matches: impl Fn(&DebugEvent) -> bool) -> bool {
        self.events().iter().any(matches)
    }

    pub fn count(&self, matches: impl Fn(&&DebugEvent) -> bool) -> usize {
        self.events().iter().filter(matches).count()
    }

    pub fn breakpoints(&self, path: &str) -> Vec<Breakpoint> {
        self.events()
            .into_iter()
            .rev()
            .find_map(|event| match event {
                DebugEvent::Breakpoints {
                    path: reported,
                    breakpoints,
                } if reported == path => Some(breakpoints),
                _ => None,
            })
            .unwrap_or_default()
    }

    pub fn wait(&self, what: &str, matches: impl Fn(&DebugEvent) -> bool) -> DebugEvent {
        let deadline = Instant::now() + Duration::from_secs(20);
        while Instant::now() < deadline {
            if let Some(event) = self.events().into_iter().find(&matches) {
                return event;
            }
            sleep(Duration::from_millis(20));
        }
        panic!("timed out waiting for {what}, saw {:?}", self.events());
    }
}

pub fn stopped(event: &DebugEvent, expected: &str) -> bool {
    matches!(event, DebugEvent::Stopped { reason, .. } if reason == expected)
}

pub fn alive(pid: u32) -> bool {
    Command::new("/bin/kill")
        .arg("-0")
        .arg(pid.to_string())
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

pub fn until(what: &str, ready: impl Fn() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(10);
    while Instant::now() < deadline {
        if ready() {
            return;
        }
        sleep(Duration::from_millis(20));
    }
    panic!("timed out waiting for {what}");
}

pub fn developer_mode() -> bool {
    Command::new("/usr/sbin/DevToolsSecurity")
        .arg("-status")
        .output()
        .map(|output| String::from_utf8_lossy(&output.stdout).contains("enabled"))
        .unwrap_or(false)
}
