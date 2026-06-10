use codex_protocol::capabilities::SelectedCapabilityRoot;
use std::sync::Mutex;

use crate::SkillsExtensionConfig;
use crate::catalog::SkillCatalog;
use crate::catalog::SkillCatalogEntry;

#[derive(Debug)]
pub(crate) struct SkillsThreadState {
    config: Mutex<SkillsExtensionConfig>,
    selected_roots: Vec<SelectedCapabilityRoot>,
}

impl SkillsThreadState {
    pub(crate) fn new(
        config: SkillsExtensionConfig,
        selected_roots: Vec<SelectedCapabilityRoot>,
    ) -> Self {
        Self {
            config: Mutex::new(config),
            selected_roots,
        }
    }

    pub(crate) fn config(&self) -> SkillsExtensionConfig {
        self.config
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clone()
    }

    pub(crate) fn set_config(&self, config: SkillsExtensionConfig) {
        *self
            .config
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner) = config;
    }

    pub(crate) fn selected_roots(&self) -> &[SelectedCapabilityRoot] {
        &self.selected_roots
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct SkillsTurnState {
    pub(crate) catalog: SkillCatalog,
    pub(crate) selected_entries: Vec<SkillCatalogEntry>,
    pub(crate) warnings: Vec<String>,
    pub(crate) main_prompts_injected: bool,
}
