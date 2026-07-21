const actionBar = document.getElementById('actionBar');
const actionTitle = document.getElementById('actionTitle');
const actionSubtitle = document.getElementById('actionSubtitle');
const actionKeys = document.getElementById('actionKeys');

const repoNote = document.getElementById('repoNote');
const repoTitle = document.getElementById('repoTitle');
const repoVehicle = document.getElementById('repoVehicle');
const repoPlate = document.getElementById('repoPlate');
const repoLocations = document.getElementById('repoLocations');
const repoHintBox = document.getElementById('repoHintBox');
const repoHintLabel = document.getElementById('repoHintLabel');
const repoHint = document.getElementById('repoHint');

const rtvMenu = document.getElementById('rtvMenu');
const menuTitle = document.getElementById('menuTitle');
const menuSubtitle = document.getElementById('menuSubtitle');
const menuOptions = document.getElementById('menuOptions');
const menuClose = document.getElementById('menuClose');

const rtvConfirm = document.getElementById('rtvConfirm');
const confirmTitle = document.getElementById('confirmTitle');
const confirmMessage = document.getElementById('confirmMessage');
const confirmCancel = document.getElementById('confirmCancel');
const confirmAccept = document.getElementById('confirmAccept');

const rtvProgress = document.getElementById('rtvProgress');
const progressTitle = document.getElementById('progressTitle');
const progressLabel = document.getElementById('progressLabel');
const progressFill = document.getElementById('progressFill');
const progressHint = document.getElementById('progressHint');

const toastContainer = document.getElementById('toastContainer');

const repoDashboard = document.getElementById('repoDashboard');
const repoDashClose = document.getElementById('repoDashClose');
const repoDashSubtitle = document.getElementById('repoDashSubtitle');
const repoDashLevel = document.getElementById('repoDashLevel');
const repoDashXpFill = document.getElementById('repoDashXpFill');
const repoDashXpText = document.getElementById('repoDashXpText');
const repoDashSkillPoints = document.getElementById('repoDashSkillPoints');
const repoDashWeeklyRepos = document.getElementById('repoDashWeeklyRepos');
const repoDashWeeklyXp = document.getElementById('repoDashWeeklyXp');
const repoDashActiveStatus = document.getElementById('repoDashActiveStatus');
const repoDashActiveInfo = document.getElementById('repoDashActiveInfo');
const repoContractStatus = document.getElementById('repoContractStatus');
const repoContractInfo = document.getElementById('repoContractInfo');
const repoContractBadges = document.getElementById('repoContractBadges');
const repoActionStart = document.getElementById('repoActionStart');
const repoActionCancel = document.getElementById('repoActionCancel');
const repoActionReturn = document.getElementById('repoActionReturn');
const repoActionRefresh = document.getElementById('repoActionRefresh');
const repoActionHint = document.getElementById('repoActionHint');
const repoStatSuccess = document.getElementById('repoStatSuccess');
const repoStatCancelled = document.getElementById('repoStatCancelled');
const repoStatMoney = document.getElementById('repoStatMoney');
const repoStatMaterials = document.getElementById('repoStatMaterials');
const repoSkillTree = document.getElementById('repoSkillTree');
const repoSkillTreeViewport = document.getElementById('repoSkillTreeViewport');
const repoSkillTreeCanvas = document.getElementById('repoSkillTreeCanvas');
const repoSkillTreeSvg = document.getElementById('repoSkillTreeSvg');
const repoSkillDetails = document.getElementById('repoSkillDetails');
const repoLeaderboardList = document.getElementById('repoLeaderboardList');
const leaderboardModes = document.querySelectorAll('.leaderboard-mode');
const repoDashTabs = document.querySelectorAll('.repo-tab');
const repoDashPanels = document.querySelectorAll('.repo-tab-panel');

const rtvRankTitle = document.getElementById('rtvRankTitle');
const rtvRankLevelMirror = document.getElementById('rtvRankLevelMirror');
const rtvSideRank = document.getElementById('rtvSideRank');


let repoTimer = null;
let actionHideTimer = null;
let currentMenuId = null;
let currentRepoSkills = [];
let currentLeaderboard = {};
let currentLeaderboardMode = 'weekly';
let isSkillTreeDragging = false;
let skillTreeDragStart = { x: 0, y: 0, scrollLeft: 0, scrollTop: 0 };

function postReady() {
    fetch(`https://${GetParentResourceName()}/rtvTowingUiReady`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(() => {});
}

function postNui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function clearChildren(element) {
    while (element.firstChild) element.removeChild(element.firstChild);
}

function normalizeKey(key) {
    if (!key) return 'KEY';
    const map = { MOUSE_LEFT: 'LMB', MOUSE_RIGHT: 'RMB', BACK: 'BACKSPACE', RETURN: 'ENTER', ESCAPE: 'ESC', ' ': 'SPACE' };
    return map[key] || String(key).toUpperCase();
}

function getToastIcon(type) {
    if (type === 'success') return '✓';
    if (type === 'error') return '!';
    if (type === 'warning') return '!';
    return 'i';
}

function showActionBar(data = {}) {
    clearTimeout(actionHideTimer);
    actionTitle.textContent = data.title || 'RTV Towing';
    actionSubtitle.textContent = data.subtitle || 'Actieve bediening';
    clearChildren(actionKeys);

    const keys = Array.isArray(data.keys) ? data.keys : [];
    keys.forEach((item) => {
        const wrapper = document.createElement('div');
        wrapper.className = 'key-item';
        const key = document.createElement('span');
        key.className = 'key-cap';
        key.textContent = normalizeKey(item.key);
        const label = document.createElement('span');
        label.className = 'key-label';
        label.textContent = item.label || '';
        wrapper.appendChild(key);
        wrapper.appendChild(label);
        actionKeys.appendChild(wrapper);
    });

    actionBar.classList.remove('hiding');
    actionBar.classList.remove('hidden');
}

function hideActionBar() {
    if (actionBar.classList.contains('hidden')) return;
    actionBar.classList.add('hiding');
    actionHideTimer = setTimeout(() => {
        actionBar.classList.add('hidden');
        actionBar.classList.remove('hiding');
    }, 180);
}

function showToast(data = {}) {
    const type = data.type || 'info';
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const icon = document.createElement('div');
    icon.className = 'toast-icon';
    icon.textContent = getToastIcon(type);

    const content = document.createElement('div');
    content.className = 'toast-content';

    const title = document.createElement('p');
    title.className = 'toast-title';
    title.textContent = data.title || 'RTV Dispatch';

    const message = document.createElement('p');
    message.className = 'toast-message';
    message.textContent = data.message || '';

    const progress = document.createElement('div');
    progress.className = 'toast-progress';

    content.appendChild(title);
    content.appendChild(message);
    toast.appendChild(icon);
    toast.appendChild(content);
    toast.appendChild(progress);
    toastContainer.appendChild(toast);

    const duration = Number(data.duration || 4500);
    progress.style.animationDuration = `${duration}ms`;

    setTimeout(() => {
        toast.classList.add('hiding');
        setTimeout(() => toast.remove(), 180);
    }, duration);
}

function showRepoNote(data = {}) {
    clearTimeout(repoTimer);
    repoTitle.textContent = data.title || 'Repo Note';
    repoVehicle.textContent = data.vehicle || 'Onbekend';
    repoPlate.textContent = data.plate || 'Onbekend';

    if (repoLocations) clearChildren(repoLocations);

    const hint = data.hint || '';
    if (repoHintBox && repoHint && repoHintLabel) {
        if (hint) {
            repoHintLabel.textContent = data.hintLabel || 'Voertuig hint';
            repoHint.textContent = hint;
            repoHintBox.classList.remove('hidden');
        } else {
            repoHintBox.classList.add('hidden');
            repoHint.textContent = '';
        }
    }

    repoNote.classList.remove('hidden');

    const duration = Number(data.duration || 0);
    if (!data.persistent && duration > 0) {
        repoTimer = setTimeout(() => repoNote.classList.add('hidden'), duration);
    }
}

function hideRepoNote() {
    clearTimeout(repoTimer);
    repoNote.classList.add('hidden');
    if (repoHintBox) repoHintBox.classList.add('hidden');
}

function openMenu(data = {}) {
    currentMenuId = data.id || 'rtv_menu';
    menuTitle.textContent = data.title || 'RTV Towing';
    menuSubtitle.textContent = data.subtitle || '';
    clearChildren(menuOptions);

    const options = Array.isArray(data.options) ? data.options : [];
    options.forEach((option) => {
        const button = document.createElement('button');
        button.className = `menu-option menu-option-${option.variant || 'default'}`;
        if (option.disabled) { button.classList.add('disabled'); button.disabled = true; }

        const icon = document.createElement('div');
        icon.className = 'menu-option-icon';
        icon.textContent = option.icon || '›';

        const body = document.createElement('div');
        body.className = 'menu-option-body';
        const title = document.createElement('strong');
        title.textContent = option.title || 'Optie';
        const description = document.createElement('p');
        description.textContent = option.description || '';
        body.appendChild(title);
        if (option.description) body.appendChild(description);

        if (Array.isArray(option.metadata) && option.metadata.length > 0) {
            const meta = document.createElement('div');
            meta.className = 'menu-meta';
            option.metadata.forEach((row) => {
                const item = document.createElement('span');
                item.textContent = `${row.label}: ${row.value}`;
                meta.appendChild(item);
            });
            body.appendChild(meta);
        }

        button.appendChild(icon);
        button.appendChild(body);
        button.addEventListener('click', () => {
            if (option.disabled) return;
            postNui('rtvTowingMenuSelect', { menuId: currentMenuId, optionId: option.id });
        });
        menuOptions.appendChild(button);
    });

    rtvMenu.classList.remove('hidden');
}

function closeMenu() { currentMenuId = null; rtvMenu.classList.add('hidden'); }
function openConfirm(data = {}) { confirmTitle.textContent = data.title || 'Bevestigen'; confirmMessage.textContent = data.message || ''; confirmAccept.textContent = data.confirmLabel || 'Bevestigen'; confirmCancel.textContent = data.cancelLabel || 'Annuleren'; rtvConfirm.classList.remove('hidden'); }
function closeConfirm() { rtvConfirm.classList.add('hidden'); }

function showProgress(data = {}) {
    progressTitle.textContent = data.title || 'RTV Towing';
    progressLabel.textContent = data.label || 'Bezig...';
    progressHint.textContent = data.canCancel ? 'Backspace om te annuleren' : '';
    progressFill.style.animation = 'none';
    progressFill.offsetHeight;
    progressFill.style.animation = `rtvProgress ${Number(data.duration || 5000)}ms linear forwards`;
    rtvProgress.classList.remove('hidden');
}
function hideProgress() { rtvProgress.classList.add('hidden'); progressFill.style.animation = 'none'; }


function formatNumber(value) {
    return new Intl.NumberFormat('nl-NL').format(Number(value || 0));
}

function formatMoney(value) {
    return `€${formatNumber(value)}`;
}

function setRepoTab(tabName) {
    repoDashTabs.forEach((tab) => tab.classList.toggle('active', tab.dataset.tab === tabName));
    repoDashPanels.forEach((panel) => {
        panel.classList.toggle('active', panel.id === `repoDash${tabName.charAt(0).toUpperCase()}${tabName.slice(1)}`);
    });
}


const skillTreeLayout = {
    better_note: { x: 500, y: 68 },
    contract_expert: { x: 780, y: 78 },
    speed_bonus: { x: 230, y: 205 },
    material_specialist_1: { x: 780, y: 205 },
    risk_reader: { x: 500, y: 335 },
    calm_operator: { x: 260, y: 510 },
    material_specialist_2: { x: 760, y: 510 },
    master_operator: { x: 500, y: 630 },
};

function getSkillPosition(skill, index, total) {
    if (skill && skillTreeLayout[skill.id]) return skillTreeLayout[skill.id];

    const columns = Math.max(1, Math.ceil(Math.sqrt(total || 1)));
    const col = index % columns;
    const row = Math.floor(index / columns);

    return {
        x: 180 + (col * 190),
        y: 120 + (row * 150),
    };
}

function getSkillById(skillId) {
    return currentRepoSkills.find((skill) => skill.id === skillId);
}

function getSkillState(skill) {
    if (skill.unlocked) return 'unlocked';
    if (skill.canUnlock) return 'available';
    return 'locked';
}

function renderSkillDetails(skill) {
    clearChildren(repoSkillDetails);

    const label = document.createElement('span');
    label.className = 'repo-dash-label';
    label.textContent = 'Skill details';

    const title = document.createElement('strong');
    title.textContent = skill ? (skill.label || skill.id || 'Skill') : 'Kies een node';

    const meta = document.createElement('div');
    meta.className = 'repo-skill-detail-meta';

    if (skill) {
        const rows = [
            `${skill.tree || 'Repo'} tree`,
            `Level ${skill.level || 1} nodig`,
            `${skill.cost || 1} skill point${Number(skill.cost || 1) === 1 ? '' : 's'}`,
        ];

        rows.forEach((row) => {
            const item = document.createElement('span');
            item.textContent = row;
            meta.appendChild(item);
        });
    }

    const desc = document.createElement('p');
    desc.textContent = skill
        ? (skill.description || 'Geen omschrijving beschikbaar.')
        : 'Klik op een skill in de tree om te zien wat hij doet en of je hem kunt vrijspelen.';

    const state = document.createElement('div');
    state.className = 'repo-skill-detail-state';

    const action = document.createElement('button');
    action.className = 'repo-skill-button detail';

    if (!skill) {
        state.textContent = 'Geen skill geselecteerd.';
        action.textContent = 'Selecteer een skill';
        action.disabled = true;
    } else if (skill.unlocked) {
        state.textContent = 'Deze skill is al vrijgespeeld.';
        action.textContent = 'Vrijgespeeld';
        action.disabled = true;
    } else if (skill.canUnlock) {
        state.textContent = 'Deze skill is beschikbaar.';
        action.textContent = 'Skill vrijspelen';
        action.addEventListener('click', () => postNui('rtvTowingRepoSkillUnlock', { skillId: skill.id }));
    } else {
        state.textContent = skill.lockedReason || 'Deze skill is nog locked.';
        action.textContent = skill.lockedReason || 'Locked';
        action.disabled = true;
    }

    repoSkillDetails.appendChild(label);
    repoSkillDetails.appendChild(title);
    repoSkillDetails.appendChild(meta);
    repoSkillDetails.appendChild(desc);
    repoSkillDetails.appendChild(state);
    repoSkillDetails.appendChild(action);
}

function renderSkillLines(skills = []) {
    clearChildren(repoSkillTreeSvg);

    const positions = {};
    skills.forEach((skill, index) => {
        positions[skill.id] = getSkillPosition(skill, index, skills.length);
    });

    skills.forEach((skill) => {
        const childPos = positions[skill.id];
        if (!childPos) return;

        const requires = Array.isArray(skill.requires) ? skill.requires : [];
        requires.forEach((parentId) => {
            const parentPos = positions[parentId];
            if (!parentPos) return;

            const parent = getSkillById(parentId);
            const line = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            const midY = parentPos.y + ((childPos.y - parentPos.y) * 0.5);
            const path = `M ${parentPos.x} ${parentPos.y} C ${parentPos.x} ${midY}, ${childPos.x} ${midY}, ${childPos.x} ${childPos.y}`;

            line.setAttribute('d', path);
            line.setAttribute('class', `repo-skill-link ${parent && parent.unlocked ? 'active' : 'locked'}`);
            repoSkillTreeSvg.appendChild(line);
        });
    });
}

function renderRepoSkills(skills = []) {
    currentRepoSkills = Array.isArray(skills) ? skills : [];
    clearChildren(repoSkillTree);
    clearChildren(repoSkillTreeSvg);

    if (!Array.isArray(skills) || skills.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'repo-skill-empty';
        empty.textContent = 'Geen skills gevonden.';
        repoSkillTree.appendChild(empty);
        renderSkillDetails(null);
        return;
    }

    renderSkillLines(skills);

    skills.forEach((skill, index) => {
        const pos = getSkillPosition(skill, index, skills.length);
        const node = document.createElement('button');
        const state = getSkillState(skill);

        node.className = `repo-skill-node ${state}`;
        node.style.left = `${pos.x}px`;
        node.style.top = `${pos.y}px`;
        node.dataset.skillId = skill.id || '';

        const icon = document.createElement('span');
        icon.className = 'repo-skill-node-icon';
        icon.textContent = skill.icon || '•';

        const label = document.createElement('strong');
        label.textContent = skill.label || skill.id || 'Skill';

        const meta = document.createElement('small');
        meta.textContent = skill.unlocked
            ? 'Vrijgespeeld'
            : (skill.canUnlock ? 'Beschikbaar' : (skill.lockedReason || `Level ${skill.level || 1}`));

        node.appendChild(icon);
        node.appendChild(label);
        node.appendChild(meta);

        node.addEventListener('click', () => {
            document.querySelectorAll('.repo-skill-node.selected').forEach((item) => item.classList.remove('selected'));
            node.classList.add('selected');
            renderSkillDetails(skill);
        });

        repoSkillTree.appendChild(node);
    });

    const firstAvailable = skills.find((skill) => skill.canUnlock) || skills.find((skill) => !skill.unlocked) || skills[0];
    renderSkillDetails(firstAvailable);

    if (repoSkillTreeViewport && !repoSkillTreeViewport.dataset.initialScrollDone) {
        repoSkillTreeViewport.scrollLeft = 230;
        repoSkillTreeViewport.scrollTop = 0;
        repoSkillTreeViewport.dataset.initialScrollDone = 'true';
    }
}

function renderLeaderboard(leaderboard = {}, mode = currentLeaderboardMode) {
    currentLeaderboard = leaderboard || {};
    currentLeaderboardMode = mode || 'weekly';

    if (!repoLeaderboardList) return;

    clearChildren(repoLeaderboardList);

    leaderboardModes.forEach((button) => {
        button.classList.toggle('active', button.dataset.board === currentLeaderboardMode);
    });

    const rows = currentLeaderboard[currentLeaderboardMode] || [];

    if (!Array.isArray(rows) || rows.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'repo-leaderboard-empty';
        empty.textContent = 'Nog geen scores gevonden. Tijd om repo’s te draaien.';
        repoLeaderboardList.appendChild(empty);
        return;
    }

    rows.forEach((row, index) => {
        const item = document.createElement('div');
        item.className = `repo-leaderboard-row rank-${index + 1}`;

        const rank = document.createElement('div');
        rank.className = 'repo-leaderboard-rank';
        rank.textContent = `#${row.rank || index + 1}`;

        const body = document.createElement('div');
        body.className = 'repo-leaderboard-body';

        const name = document.createElement('strong');
        name.textContent = row.name || 'Onbekende medewerker';

        const sub = document.createElement('span');

        if (currentLeaderboardMode === 'weekly') {
            sub.textContent = `${formatNumber(row.weeklyRepos || 0)} repo's deze week • ${formatNumber(row.weeklyXp || 0)} XP`;
        } else if (currentLeaderboardMode === 'materials') {
            sub.textContent = `${formatNumber(row.totalMaterials || 0)} parts totaal • ${formatNumber(row.successfulRepos || 0)} repo's`;
        } else {
            sub.textContent = `${formatNumber(row.successfulRepos || 0)} repo's totaal • ${formatNumber(row.totalXp || 0)} XP`;
        }

        body.appendChild(name);
        body.appendChild(sub);

        const right = document.createElement('div');
        right.className = 'repo-leaderboard-score';

        if (currentLeaderboardMode === 'weekly') {
            right.innerHTML = `<strong>${formatNumber(row.weeklyRepos || 0)}</strong><span>repo's</span>`;
        } else if (currentLeaderboardMode === 'materials') {
            right.innerHTML = `<strong>${formatNumber(row.totalMaterials || 0)}</strong><span>parts</span>`;
        } else {
            right.innerHTML = `<strong>${formatNumber(row.successfulRepos || 0)}</strong><span>repo's</span>`;
        }

        item.appendChild(rank);
        item.appendChild(body);
        item.appendChild(right);
        repoLeaderboardList.appendChild(item);
    });
}




function setButtonState(button, disabled, text) {
    if (!button) return;
    button.disabled = !!disabled;
    if (text) button.textContent = text;
}

function setRepoActionState(data = {}) {
    const active = data.active || null;
    const client = data.client || {};
    const clientActive = client.activeStatus || null;
    const displayActive = active || clientActive;

    clearChildren(repoContractBadges);

    if (displayActive) {
        repoContractStatus.textContent = displayActive.status || 'Actief';
        repoContractInfo.textContent = `${displayActive.vehicle || 'Onbekend'} • ${displayActive.plate || 'Geen kenteken'}${displayActive.premium ? ' • Premium contract' : ''}`;

        const badgeData = [];
        if (displayActive.premium) badgeData.push('Premium');
        if (displayActive.riskLevel) badgeData.push(`Risico: ${displayActive.riskLevel}`);
        if (displayActive.secured) badgeData.push('Geladen');
        if (displayActive.dropoffRevealed) badgeData.push('Afleverpunt actief');

        badgeData.forEach((label) => {
            const badge = document.createElement('span');
            badge.className = 'repo-contract-badge';
            badge.textContent = label;
            repoContractBadges.appendChild(badge);
        });
    } else {
        repoContractStatus.textContent = 'Geen actieve opdracht';
        repoContractInfo.textContent = client.hasReturnableTruck
            ? `Geen actieve repo. Vrachtwagen staat klaar${client.returnTruckPlate ? ` (${client.returnTruckPlate})` : ''}.`
            : 'Start een repo-opdracht vanuit dit dashboard.';
    }

    const canStart = client.canStartRepo !== false && !displayActive;
    const canCancel = client.canCancelRepo === true || !!displayActive;
    const canReturn = client.canReturnTruck === true;

    setButtonState(repoActionStart, !canStart, client.hasReturnableTruck ? 'Nieuwe repo met huidige vrachtwagen' : 'Repo starten');
    setButtonState(repoActionCancel, !canCancel, 'Actieve repo annuleren');
    setButtonState(repoActionReturn, !canReturn, 'Vrachtwagen terugbrengen');

    if (displayActive) {
        repoActionHint.textContent = 'Rond je huidige opdracht af of annuleer hem vanuit dit dashboard.';
    } else if (client.hasReturnableTruck) {
        repoActionHint.textContent = 'Je kunt direct een nieuwe opdracht starten met dezelfde vrachtwagen of hem terugbrengen.';
    } else {
        repoActionHint.textContent = 'Start hier je repo-opdracht. De opdracht, skills en statistieken blijven in dit dashboard zichtbaar.';
    }
}

function openRepoDashboard(data = {}) {
    const player = data.player || {};
    const stats = data.stats || {};
    const active = data.active || null;

    repoDashSubtitle.textContent = 'Welkom terug. Kies je opdracht, beheer je skills en volg de competitie.';
    repoDashLevel.textContent = player.level || 1;
    if (rtvRankLevelMirror) rtvRankLevelMirror.textContent = player.level || 1;
    if (rtvRankTitle) rtvRankTitle.textContent = `Rang ${player.level || 1}`;
    if (rtvSideRank) rtvSideRank.textContent = (player.level || 1) >= 10 ? 'Master Operator' : ((player.level || 1) >= 5 ? 'Senior Operator' : 'Recovery Operator');
    repoDashSkillPoints.textContent = player.skillPoints || 0;

    const progress = Math.max(0, Math.min(1, Number(player.progress || 0)));
    repoDashXpFill.style.width = `${Math.round(progress * 100)}%`;
    repoDashXpText.textContent = `${formatNumber(player.xpIntoLevel || 0)} / ${formatNumber(player.xpNeeded || 0)} XP naar volgend level`;

    repoDashWeeklyRepos.textContent = formatNumber(stats.weeklyRepos || 0);
    repoDashWeeklyXp.textContent = `${formatNumber(stats.weeklyXp || 0)} XP deze week`;

    const clientActive = data.client && data.client.activeStatus ? data.client.activeStatus : null;
    const displayActive = active || clientActive;

    if (displayActive) {
        repoDashActiveStatus.textContent = displayActive.status || 'Actief';
        repoDashActiveInfo.textContent = `${displayActive.vehicle || 'Onbekend'} • ${displayActive.plate || 'Geen kenteken'}${displayActive.premium ? ' • Premium' : ''}`;
    } else {
        repoDashActiveStatus.textContent = 'Geen';
        repoDashActiveInfo.textContent = 'Geen actieve repo.';
    }

    setRepoActionState(data);

    repoStatSuccess.textContent = formatNumber(stats.successfulRepos || 0);
    repoStatCancelled.textContent = formatNumber(stats.cancelledRepos || 0);
    repoStatMoney.textContent = formatMoney(stats.totalMoney || 0);
    repoStatMaterials.textContent = formatNumber(stats.totalMaterials || 0);

    renderRepoSkills(data.skills || []);
    renderLeaderboard(data.leaderboard || {}, currentLeaderboardMode);
    repoDashboard.classList.remove('hidden');
}

function closeRepoDashboard() {
    repoDashboard.classList.add('hidden');
}

function hideAll() {
    hideActionBar();
    repoNote.classList.add('hidden');
    closeMenu();
    closeConfirm();
    hideProgress();
    closeRepoDashboard();
    clearChildren(toastContainer);
}

menuClose.addEventListener('click', () => postNui('rtvTowingMenuClose'));
repoDashClose.addEventListener('click', () => postNui('rtvTowingRepoDashboardClose'));
repoDashTabs.forEach((tab) => tab.addEventListener('click', () => setRepoTab(tab.dataset.tab || 'contract')));
if (repoActionStart) repoActionStart.addEventListener('click', () => postNui('rtvTowingRepoAction', { action: 'start' }));
if (repoActionCancel) repoActionCancel.addEventListener('click', () => postNui('rtvTowingRepoAction', { action: 'cancel' }));
if (repoActionReturn) repoActionReturn.addEventListener('click', () => postNui('rtvTowingRepoAction', { action: 'returnTruck' }));
if (repoActionRefresh) repoActionRefresh.addEventListener('click', () => postNui('rtvTowingRepoAction', { action: 'refresh' }));
leaderboardModes.forEach((button) => {
    button.addEventListener('click', () => renderLeaderboard(currentLeaderboard, button.dataset.board || 'weekly'));
});

if (repoSkillTreeViewport) {
    repoSkillTreeViewport.addEventListener('pointerdown', (event) => {
        if (event.target && event.target.closest && event.target.closest('.repo-skill-node')) return;
        isSkillTreeDragging = true;
        skillTreeDragStart = {
            x: event.clientX,
            y: event.clientY,
            scrollLeft: repoSkillTreeViewport.scrollLeft,
            scrollTop: repoSkillTreeViewport.scrollTop,
        };
        repoSkillTreeViewport.classList.add('dragging');
    });

    window.addEventListener('pointermove', (event) => {
        if (!isSkillTreeDragging) return;
        const dx = event.clientX - skillTreeDragStart.x;
        const dy = event.clientY - skillTreeDragStart.y;
        repoSkillTreeViewport.scrollLeft = skillTreeDragStart.scrollLeft - dx;
        repoSkillTreeViewport.scrollTop = skillTreeDragStart.scrollTop - dy;
    });

    window.addEventListener('pointerup', () => {
        isSkillTreeDragging = false;
        repoSkillTreeViewport.classList.remove('dragging');
    });
}

confirmAccept.addEventListener('click', () => postNui('rtvTowingConfirmResult', { accepted: true }));
confirmCancel.addEventListener('click', () => postNui('rtvTowingConfirmResult', { accepted: false }));

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        if (!rtvMenu.classList.contains('hidden')) postNui('rtvTowingMenuClose');
        if (!rtvConfirm.classList.contains('hidden')) postNui('rtvTowingConfirmResult', { accepted: false });
        if (!repoDashboard.classList.contains('hidden')) postNui('rtvTowingRepoDashboardClose');
    }
});

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    const action = payload.action;
    const data = payload.data || {};

    if (action === 'showActionBar') return showActionBar(data);
    if (action === 'hideActionBar') return hideActionBar();
    if (action === 'showToast') return showToast(data);
    if (action === 'showRepoNote') return showRepoNote(data);
    if (action === 'hideRepoNote') return hideRepoNote();
    if (action === 'openMenu') return openMenu(data);
    if (action === 'closeMenu') return closeMenu();
    if (action === 'openConfirm') return openConfirm(data);
    if (action === 'closeConfirm') return closeConfirm();
    if (action === 'showProgress') return showProgress(data);
    if (action === 'hideProgress') return hideProgress();
    if (action === 'openRepoDashboard') return openRepoDashboard(data);
    if (action === 'closeRepoDashboard') return closeRepoDashboard();
    if (action === 'hideAll') return hideAll();
});

postReady();
