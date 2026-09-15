pub mod proto;

pub struct Packet {
    pub bytes: u32,
}

pub fn wrap(bytes: u32) -> Packet {
    Packet { bytes }
}
