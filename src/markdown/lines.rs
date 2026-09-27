pub struct LineIndex {
    starts: Vec<usize>,
}

impl LineIndex {
    pub fn new(text: &str) -> Self {
        let mut starts = vec![0];
        starts.extend(
            text.bytes()
                .enumerate()
                .filter(|(_, b)| *b == b'\n')
                .map(|(i, _)| i + 1),
        );
        Self { starts }
    }

    pub fn line_at(&self, byte: usize) -> usize {
        match self.starts.binary_search(&byte) {
            Ok(i) => i + 1,
            Err(i) => i,
        }
    }
}
