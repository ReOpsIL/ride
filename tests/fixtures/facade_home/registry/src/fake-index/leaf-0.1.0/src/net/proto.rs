pub enum Kind {
    Tcp,
    Udp,
}

pub fn parse(text: &str) -> Kind {
    if text == "udp" { Kind::Udp } else { Kind::Tcp }
}
