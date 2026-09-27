use std::collections::HashMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct Relations {
    bases: HashMap<String, Vec<String>>,
    impls: HashMap<String, Vec<String>>,
}

impl Relations {
    pub fn add_bases(&mut self, name: String, bases: Vec<String>) {
        if !bases.is_empty() {
            self.bases.insert(name, bases);
        }
    }

    pub fn add_impl(&mut self, type_name: String, trait_name: String) {
        if type_name == trait_name {
            return;
        }
        let traits = self.impls.entry(type_name).or_default();
        if !traits.contains(&trait_name) {
            traits.push(trait_name);
        }
    }

    pub fn impls_of(&self, type_name: &str) -> Vec<String> {
        self.impls.get(type_name).cloned().unwrap_or_default()
    }

    pub fn implementors_of(&self, trait_name: &str) -> Vec<String> {
        self.impls
            .iter()
            .filter(|(_, traits)| traits.iter().any(|t| t == trait_name))
            .map(|(type_name, _)| type_name.clone())
            .collect()
    }

    pub fn derived_of(&self, name: &str) -> Vec<String> {
        self.bases
            .iter()
            .filter(|(_, bases)| bases.iter().any(|b| b == name))
            .map(|(derived, _)| derived.clone())
            .collect()
    }

    pub fn bases_of(&self, name: &str) -> Vec<String> {
        self.bases.get(name).cloned().unwrap_or_default()
    }
}
