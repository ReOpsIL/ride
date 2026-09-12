use crate::ffi::DebugState;

use super::DebugSession;

impl DebugSession {
    pub(super) fn transition(&self, state: DebugState) -> bool {
        let ending = matches!(state, DebugState::Terminated | DebugState::Exited { .. });
        let entered =
            self.replace_state(|current| !matches!(current, DebugState::Terminated), state);
        if entered && ending {
            self.retire();
        }
        entered
    }

    pub(super) fn begin_running(&self) -> bool {
        self.replace_state(
            |current| matches!(current, DebugState::Launching),
            DebugState::Running,
        )
    }

    fn replace_state(&self, allowed: impl Fn(&DebugState) -> bool, state: DebugState) -> bool {
        let mut current = self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if !allowed(&current) {
            return false;
        }
        *current = state;
        true
    }

    pub(super) fn fail(&self, message: &str) {
        if !self.transition(DebugState::Terminated) {
            return;
        }
        self.transport.shutdown();
        self.emit_failure(message);
    }

    pub(super) fn abandon_launch(&self, message: &str) -> bool {
        let entered = self.replace_state(
            |current| matches!(current, DebugState::Launching),
            DebugState::Terminated,
        );
        if !entered {
            return false;
        }
        self.transport.shutdown();
        self.retire();
        self.emit_failure(message);
        true
    }

    pub(super) fn retire(&self) {
        self.registration.retire();
    }

    pub(super) fn finished(&self) -> bool {
        matches!(self.state(), DebugState::Terminated)
    }

    pub(super) fn ended(&self) -> bool {
        matches!(
            self.state(),
            DebugState::Terminated | DebugState::Exited { .. }
        )
    }
}
