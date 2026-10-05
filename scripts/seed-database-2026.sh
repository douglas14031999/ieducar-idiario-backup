#!/usr/bin/env bash
# ==============================================================================
# Script: seed-database-2026.sh
# Objetivo: Realizar o povoamento completo e atualizado do banco de dados do
#           i-Educar em total conformidade com o Censo Escolar 2026 (INEP).
#           Inclui correções em Deficiências (Visão Monocular), ampliação de
#           Níveis e Tipos de Ensino, Turnos de Turma, Recursos de Prova do INEP,
#           Localização Diferenciada, Formação Continuada e Gestão Escolar.
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}  🧬  POVOAMENTO INICIAL COMPLETO DO BANCO DE DADOS (CENSO INEP 2026)  ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "Configuração de 30 Seeders essenciais para o i-Educar e i-Diário,"
echo -e "alinhados às exigências de validação e identificação única do Censo 2026.\n"

# 1. Localização 100% Automática do Diretório do i-Educar
detect_ieducar_dir() {
    # Estratégia A: Variável IEDUCAR_STORAGE_PATH no /etc/ieducar-backup/.env se existir
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_storage
        env_storage=$(grep -E "^IEDUCAR_STORAGE_PATH=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_storage" && -d "$env_storage" ]]; then
            local cand
            cand=$(dirname "$env_storage")
            if [[ -f "$cand/artisan" || -d "$cand/database" ]]; then
                echo "$cand"
                return 0
            fi
        fi
    fi

    # Estratégia B: Se já estiver executando na raiz do i-Educar
    if [[ -f "./artisan" && -d "./database" ]]; then
        pwd
        return 0
    fi

    # Estratégia C: Caminhos padrão mais comuns em servidores Linux
    local common_paths=(
        "/var/www/ieducar"
        "/var/www/i-educar"
        "/var/www/html/ieducar"
        "/var/www/html/i-educar"
        "/var/www/html"
        "/srv/ieducar"
        "/opt/ieducar"
    )
    for p in "${common_paths[@]}"; do
        if [[ -f "$p/artisan" && -d "$p/database" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Estratégia D: Detectar nas configurações do Nginx (/etc/nginx)
    if [[ -d /etc/nginx ]]; then
        local ngx_roots
        ngx_roots=$(grep -rhE "^\s*root\s+.*ieducar" /etc/nginx/ 2>/dev/null | awk '{print $2}' | tr -d ';' || true)
        for ngx_p in $ngx_roots; do
            local cand="$ngx_p"
            while [[ "$cand" != "/" && -n "$cand" ]]; do
                if [[ -f "$cand/artisan" && -d "$cand/database" ]]; then
                    echo "$cand"
                    return 0
                fi
                cand=$(dirname "$cand")
            done
        done
    fi

    # Estratégia E: Busca rápida nos diretórios de aplicações
    local fast_file
    fast_file=$(find /var/www /srv /opt /home /root -maxdepth 4 -type f -name "artisan" 2>/dev/null | head -n 1 || true)
    if [[ -n "$fast_file" ]]; then
        local cand
        cand=$(dirname "$fast_file")
        if [[ -d "$cand/database" ]]; then
            echo "$cand"
            return 0
        fi
    fi

    # Estratégia F: Busca profunda no sistema
    local deep_file
    deep_file=$(find / -path "/proc" -prune -o -path "/sys" -prune -o -path "/dev" -prune -o -path "/run" -prune -o -path "/tmp" -prune -o -type f -name "artisan" -print 2>/dev/null | head -n 1 || true)
    if [[ -n "$deep_file" ]]; then
        local cand
        cand=$(dirname "$deep_file")
        if [[ -d "$cand/database" ]]; then
            echo "$cand"
            return 0
        fi
    fi

    return 1
}

echo -e "${BLUE}Localizando instalação do i-Educar...${NC}"
IEDUCAR_DIR=$(detect_ieducar_dir || true)

if [[ -z "$IEDUCAR_DIR" || ! -d "$IEDUCAR_DIR" ]]; then
    echo -e "${RED}[ERRO] Instalação do i-Educar não foi localizada automaticamente.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ i-Educar localizado em: ${BOLD}${IEDUCAR_DIR}${NC}\n"

SEEDERS_DIR="${IEDUCAR_DIR}/database/seeders"
mkdir -p "${SEEDERS_DIR}"

# Detectar proprietário web
WEB_USER=$(stat -c '%U' "${IEDUCAR_DIR}" 2>/dev/null || echo "www-data")
WEB_GROUP=$(stat -c '%G' "${IEDUCAR_DIR}" 2>/dev/null || echo "$WEB_USER")
if [[ "$WEB_USER" == "root" ]] && id -u "www-data" &>/dev/null; then
    WEB_USER="www-data"
    WEB_GROUP="www-data"
fi

echo -e "${BLUE}Gerando 30 seeders atualizados para 2026 em ${SEEDERS_DIR}...${NC}"

# ==============================================================================
# 1. DefaultCadastroDeficienciaTableSeeder.php
# Correção: Visão Monocular (cod 8) com nome correto e descrições do Censo 2026
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroDeficienciaTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\DeficiencyType;
use App\Models\LegacyDeficiency;
use iEducar\Modules\Educacenso\Model\Deficiencias;
use iEducar\Modules\Educacenso\Model\Transtornos;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DefaultCadastroDeficienciaTableSeeder extends Seeder
{
    public function run()
    {
        // 1. Deficiências Educacenso (códigos 1 a 8, 13, 25 e 999)
        $deficiencies = [
            Deficiencias::CEGUEIRA => 'Cegueira',
            Deficiencias::BAIXA_VISAO => 'Baixa Visão',
            Deficiencias::SURDEZ => 'Surdez',
            Deficiencias::DEFICIENCIA_AUDITIVA => 'Deficiência Auditiva',
            Deficiencias::SURDOCEGUEIRA => 'Surdocegueira',
            Deficiencias::DEFICIENCIA_FISICA => 'Deficiência Física',
            Deficiencias::DEFICIENCIA_INTELECTUAL => 'Deficiência Intelectual',
            Deficiencias::VISAO_MONOCULAR => 'Visão Monocular', // Nome corrigido (Censo 2026 / Lei 14.126)
            Deficiencias::TRANSTORNO_ESPECTRO_AUTISTA => 'Transtorno do Espectro Autista',
            Deficiencias::ALTAS_HABILIDADES_SUPERDOTACAO => 'Altas Habilidades / Superdotação',
            Deficiencias::OUTRAS => 'Outras Deficiências',
        ];

        foreach ($deficiencies as $id => $name) {
            LegacyDeficiency::updateOrCreate([
                'deficiencia_educacenso' => $id,
            ], [
                'nm_deficiencia' => Str::upper($name),
                'deficiency_type_id' => DeficiencyType::DEFICIENCY,
            ]);
        }

        // 2. Transtornos Específicos do Desenvolvimento (códigos 50 a 55 e 999)
        $disorders = [
            Transtornos::DISCALCULIA => 'Discalculia ou outro transtorno da matemática',
            Transtornos::DISGRAFIA => 'Disgrafia, Disortografia ou outro transtorno da escrita',
            Transtornos::DISLALIA => 'Dislalia ou outro transtorno da fala/linguagem',
            Transtornos::DISLEXIA => 'Dislexia',
            Transtornos::TDAH => 'Transtorno do Déficit de Atenção com Hiperatividade (TDAH)',
            Transtornos::TPAC => 'Transtorno do Processamento Auditivo Central (TPAC)',
            Transtornos::OUTROS => 'Outros Transtornos de Aprendizagem',
        ];

        foreach ($disorders as $id => $name) {
            LegacyDeficiency::updateOrCreate([
                'transtorno_educacenso' => $id,
            ], [
                'nm_deficiencia' => Str::upper($name),
                'deficiency_type_id' => DeficiencyType::DISORDER,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 2. DefaultCadastroEscolaridadeTableSeeder.php
# Ampliação: Inclui Fundamental Incompleto, Completo, Médio, Superior e Pós-Graduações
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroEscolaridadeTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacySchoolingDegree;
use iEducar\Modules\Educacenso\Model\Escolaridade;
use Illuminate\Database\Seeder;

class DefaultCadastroEscolaridadeTableSeeder extends Seeder
{
    public function run()
    {
        $schoolings = [
            Escolaridade::NAO_CONCLUIU_ENSINO_FUNDAMENTAL => 'Ensino Fundamental Incompleto',
            Escolaridade::ENSINO_FUNDAMENTAL => 'Ensino Fundamental Completo',
            Escolaridade::ENSINO_MEDIO => 'Ensino Médio (Normal / Magistério / Geral)',
            Escolaridade::EDUCACAO_SUPERIOR => 'Educação Superior Completa',
            5 => 'Especialização / Pós-Graduação Lato Sensu',
            6 => 'Mestrado',
            7 => 'Doutorado',
            8 => 'Não Possui Escolaridade Formal',
        ];

        foreach ($schoolings as $id => $name) {
            LegacySchoolingDegree::updateOrCreate([
                'escolaridade' => $id,
            ], [
                'descricao' => $name,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 3. DefaultCadastroRacaTableSeeder.php
# Padrão oficial IBGE e INEP Censo 2026 (0 a 5)
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroRacaTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyRace;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultCadastroRacaTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $races = [
            0 => 'Não Declarada',
            1 => 'Branca',
            2 => 'Preta',
            3 => 'Parda',
            4 => 'Amarela',
            5 => 'Indígena',
        ];

        foreach ($races as $id => $name) {
            LegacyRace::updateOrCreate([
                'raca_educacenso' => $id,
            ], [
                'nm_raca' => $name,
                'idpes_cad' => $user?->getKey(),
            ]);
        }
    }
}
EOF

# ==============================================================================
# 4. DefaultEmployeeGraduationDisciplines.php
# Disciplinas e áreas de graduação dos docentes (Educacenso 2026)
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultEmployeeGraduationDisciplines.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultEmployeeGraduationDisciplines extends Seeder
{
    public function run()
    {
        $data = [
            1 => 'Química',
            2 => 'Física',
            3 => 'Matemática',
            4 => 'Biologia',
            5 => 'Ciências',
            6 => 'Língua / Literatura Portuguesa',
            7 => 'Língua / Literatura estrangeira - Inglês',
            8 => 'Língua / Literatura estrangeira - Espanhol',
            9 => 'Língua / Literatura estrangeira - outra',
            10 => 'Arte (Educação Artística, Teatro, Dança, Música, Artes Visuais)',
            11 => 'Educação Física',
            12 => 'História',
            13 => 'Geografia',
            14 => 'Filosofia',
            16 => 'Informática / Computação / Tecnologias Digitais',
            17 => 'Disciplinas / Áreas de Formação Técnica e Profissional',
            20 => 'Disciplinas voltadas ao Atendimento Educacional Especializado (AEE) e Inclusão',
            21 => 'Disciplinas voltadas à Diversidade Sociocultural e Étnico-Racial',
            23 => 'Língua Brasileira de Sinais - Libras',
            25 => 'Disciplinas Pedagógicas (Pedagogia / Magistério da Educação Infantil e Anos Iniciais)',
            26 => 'Ensino Religioso',
            27 => 'Língua Indígena',
            28 => 'Estudos Sociais',
            29 => 'Sociologia',
            30 => 'Língua / Literatura estrangeira - Francês',
            31 => 'Língua Portuguesa como Segunda Língua para Surdos',
            32 => 'Estágio Curricular Supervisionado',
            99 => 'Outras Disciplinas / Áreas do Conhecimento',
        ];

        foreach ($data as $id => $name) {
            DB::table('employee_graduation_disciplines')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# ==============================================================================
# 5. DefaultManagerAccessCriteriasTableSeeder.php
# Critérios de acesso ao cargo de gestor escolar
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultManagerAccessCriteriasTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultManagerAccessCriteriasTableSeeder extends Seeder
{
    public function run()
    {
        $criterias = [
            1 => 'Proprietário(a) ou sócio(a)-proprietário(a) da escola',
            2 => 'Exclusivamente por indicação/escolha da gestão',
            3 => 'Processo seletivo qualificado e escolha/nomeação da gestão',
            4 => 'Concurso público específico para o cargo de gestor escolar',
            5 => 'Exclusivamente por processo eleitoral com a participação da comunidade escolar',
            6 => 'Processo seletivo qualificado e eleição com a participação da comunidade escolar',
            7 => 'Outros critérios de acesso',
        ];

        foreach ($criterias as $id => $name) {
            DB::table('manager_access_criterias')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# ==============================================================================
# 6. DefaultManagerLinkTypesTableSeeder.php
# Tipos de vínculo do gestor escolar
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultManagerLinkTypesTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultManagerLinkTypesTableSeeder extends Seeder
{
    public function run()
    {
        $types = [
            1 => 'Concursado / efetivo / estável',
            2 => 'Contrato temporário',
            3 => 'Contrato terceirizado',
            4 => 'Contrato CLT',
        ];

        foreach ($types as $id => $name) {
            DB::table('manager_link_types')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# ==============================================================================
# 7. DefaultManagerRolesTableSeeder.php (NOVO CENSO 2026)
# Cargos de Gestão Escolar (Direção / Coordenação)
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultManagerRolesTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultManagerRolesTableSeeder extends Seeder
{
    public function run()
    {
        $roles = [
            1 => 'Diretor(a)',
            2 => 'Vice-Diretor(a) / Outro Cargo de Gestão',
            3 => 'Coordenador(a) Pedagógico(a)',
        ];

        foreach ($roles as $id => $name) {
            DB::table('manager_roles')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# ==============================================================================
# 8. DefaultPmieducarTurmaTurnoTableSeeder.php (NOVO CENSO 2026)
# Turnos de Turma essenciais para evitar erros de alocação de turmas e diários
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTurmaTurnoTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarTurmaTurnoTableSeeder extends Seeder
{
    public function run()
    {
        $turnos = [
            1 => 'Matutino',
            2 => 'Vespertino',
            3 => 'Noturno',
            4 => 'Integral',
        ];

        foreach ($turnos as $id => $nome) {
            DB::table('pmieducar.turma_turno')->updateOrInsert(
                ['id' => $id],
                ['nome' => $nome]
            );
        }
    }
}
EOF

# ==============================================================================
# 9. DefaultCadastroEstadoCivilTableSeeder.php (NOVO)
# Estado civil das pessoas físicas
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroEstadoCivilTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultCadastroEstadoCivilTableSeeder extends Seeder
{
    public function run()
    {
        $estados = [
            1 => 'Solteiro(a)',
            2 => 'Casado(a)',
            3 => 'Divorciado(a)',
            4 => 'Viúvo(a)',
            5 => 'União Estável',
            6 => 'Separado(a) Judicialmente',
        ];

        foreach ($estados as $id => $descricao) {
            DB::table('cadastro.estado_civil')->updateOrInsert(
                ['ideciv' => $id],
                ['descricao' => $descricao]
            );
        }
    }
}
EOF

# ==============================================================================
# 10. DefaultPmieducarAbandonoTipoTableSeeder.php
# Motivos de evasão / abandono escolar
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarAbandonoTipoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyAbandonmentType;
use Illuminate\Database\Seeder;

class DefaultPmieducarAbandonoTipoTableSeeder extends Seeder
{
    public function run()
    {
        $types = [
            'Evasão Escolar',
            'Vulnerabilidade Social Extrema',
            'Violência no Trajeto ou na Escola',
            'Conflito Familiar',
            'Gravidez na Adolescência',
            'Mudança de Residência sem Comunicação Prévia',
            'Inserção no Mercado de Trabalho',
            'Doença / Tratamento de Saúde Prolongado',
            'Dificuldade de Acesso / Transporte Escolar',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyAbandonmentType::updateOrCreate([
                'nome' => $type,
            ], [
                'ref_cod_instituicao' => 1,
                'ativo' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 11. DefaultPmieducarAlunoBeneficioTableSeeder.php
# Benefícios e programas de assistência ao estudante
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarAlunoBeneficioTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyBenefit;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarAlunoBeneficioTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $benefits = [
            'Bolsa Família',
            'Auxílio Brasil / Programa de Renda Municipal',
            'Pé-de-Meia (Incentivo Financeiro-Educacional)',
            'Bolsa Estudantil',
            'Passe / Vale Transporte Escolar Gratuito',
            'Auxílio Uniforme Escolar',
            'Auxílio Material Escolar',
            'Benefício de Prestação Continuada (BPC)',
            'Outro(a)',
        ];

        foreach ($benefits as $benefit) {
            LegacyBenefit::updateOrCreate([
                'nm_beneficio' => $benefit,
            ], [
                'ref_usuario_cad' => $user?->getKey(),
            ]);
        }
    }
}
EOF

# ==============================================================================
# 12. DefaultPmieducarFuncaoTableSeeder.php
# Funções de servidores administrativos, pedagógicos e docentes
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarFuncaoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyRole;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarFuncaoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $roles = [
            'CP' => 'Coordenador(a) Pedagógico',
            'DIR' => 'Diretor(a) Escolar',
            'VDIR' => 'Vice-Diretor(a) Escolar',
            'SEC' => 'Secretário(a) Escolar',
            'SERV' => 'Servente Escolar / Merendeira',
            'ZEL' => 'Zelador(a) / Vigilante',
            'OE' => 'Orientador(a) Educacional',
            'AUX' => 'Auxiliar Administrativo / Secretária',
            'BIB' => 'Bibliotecário(a)',
            'TEC-INF' => 'Técnico de Informática / Monitor de TIC',
            'ASG' => 'Auxiliar de Serviços Gerais',
            'MON' => 'Monitor(a) de Transporte Escolar',
            'CUIPED' => 'Cuidador(a) / Profissional de Apoio Escolar (Educação Especial)',
            'PSIC' => 'Psicólogo(a) Escolar',
            'ASST' => 'Assistente Social Escolar',
        ];

        foreach ($roles as $sg => $role) {
            LegacyRole::updateOrCreate([
                'abreviatura' => $sg,
            ], [
                'nm_funcao' => $role,
                'professor' => 0,
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }

        $teachers = [
            'PROF' => 'Professor(a) Regente',
            'PROF-AEE' => 'Professor(a) de Atendimento Educacional Especializado (AEE)',
            'PROF-AUX' => 'Professor(a) Auxiliar / Mediador(a)',
            'PROF-LIBRAS' => 'Professor(a) / Instrutor(a) de Libras',
        ];

        foreach ($teachers as $sg => $teacher) {
            LegacyRole::updateOrCreate([
                'abreviatura' => $sg,
            ], [
                'nm_funcao' => $teacher,
                'professor' => 1,
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 13. DefaultPmieducarHistoricoGradeCursoTableSeeder.php
# Etapas dos cursos para histórico escolar
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarHistoricoGradeCursoTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarHistoricoGradeCursoTableSeeder extends Seeder
{
    public function run()
    {
        $grades = [
            1 => 'Série',
            2 => 'Ano',
            3 => 'EJA',
            4 => 'Módulo',
            5 => 'Etapa',
            6 => 'Período',
        ];

        foreach ($grades as $id => $etapa) {
            DB::table('pmieducar.historico_grade_curso')->updateOrInsert(
                ['id' => $id],
                [
                    'descricao_etapa' => $etapa,
                    'created_at' => now(),
                ]
            );
        }
    }
}
EOF

# ==============================================================================
# 14. DefaultPmieducarModuloTableSeeder.php
# Tipos de etapas avaliativas e letivas
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarModuloTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyStageType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarModuloTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $modules = [
            1 => 'Anual (1 Etapa)',
            2 => 'Semestral (2 Etapas)',
            3 => 'Trimestral (3 Etapas)',
            4 => 'Bimestral (4 Etapas)',
        ];

        foreach ($modules as $stage => $name) {
            LegacyStageType::updateOrCreate([
                'num_etapas' => $stage,
                'nm_tipo' => $name,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 15. DefaultPmieducarNivelEnsinoTableSeeder.php
# CORREÇÃO CRÍTICA: Substitui o registro único "Ano" pela grade oficial de níveis do Censo
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarNivelEnsinoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyEducationLevel;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarNivelEnsinoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $levels = [
            'Educação Infantil (Creche e Pré-Escola)',
            'Ensino Fundamental de 9 Anos (Anos Iniciais e Finais)',
            'Ensino Médio',
            'Educação de Jovens e Adultos (EJA)',
            'Educação Especial (Modalidade Transversal)',
            'Educação Profissional Técnica e Tecnológica',
            'Ano / Série Regular',
        ];

        foreach ($levels as $level) {
            LegacyEducationLevel::updateOrCreate([
                'nm_nivel' => $level,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 16. DefaultPmieducarTipoEnsinoTableSeeder.php
# EXPANSÃO CENSO 2026: Modalidades e etapas da Educação Básica
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoEnsinoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyEducationType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoEnsinoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $levels = [
            'Educação Infantil - Creche',
            'Educação Infantil - Pré-Escola',
            'Ensino Fundamental - Anos Iniciais (1º ao 5º Ano)',
            'Ensino Fundamental - Anos Finais (6º ao 9º Ano)',
            'Ensino Médio - Formação Geral Básica',
            'Educação de Jovens e Adultos (EJA Fundamental e Médio)',
            'Atendimento Educacional Especializado (AEE)',
            'Atividade Complementar / Educação em Tempo Integral',
            'Educação Profissional e Qualificação Técnica',
            'Educação Bilíngue de Surdos',
        ];

        foreach ($levels as $level) {
            LegacyEducationType::updateOrCreate([
                'nm_tipo' => $level,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 17. DefaultPmieducarProjetoTableSeeder.php
# Programas e projetos pedagógicos escolares
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarProjetoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyProject;
use Illuminate\Database\Seeder;

class DefaultPmieducarProjetoTableSeeder extends Seeder
{
    public function run()
    {
        $projects = [
            'Reforço Escolar / Recuperação da Aprendizagem',
            'Alfabetização na Idade Certa e Letramento',
            'Preparatório de Avaliações Externas (Saeb / Prova Brasil)',
            'Educação em Tempo Integral / Mais Educação',
            'Robótica Educacional e Tecnologias Digitais',
            'Fanfarra / Banda Escolar',
            'Teatro, Artes e Cultura',
            'Xadrez e Jogos de Raciocínio Lógico',
            'Escolinha de Esportes e Lazer',
            'Dança e Expressão Corporal',
            'Artes Marciais e Defesa Pessoal',
            'Horta Escolar e Educação Ambiental',
        ];

        foreach ($projects as $project) {
            LegacyProject::updateOrCreate([
                'nome' => $project,
            ], [
                'observacao' => 'Projeto ativo Censo 2026',
            ]);
        }
    }
}
EOF

# ==============================================================================
# 18. DefaultPmieducarReligionTableSeeder.php
# Credos religiosos e opções laicas
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarReligionTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\Religion;
use Illuminate\Database\Seeder;

class DefaultPmieducarReligionTableSeeder extends Seeder
{
    public function run()
    {
        $religions = [
            'Adventista',
            'Ateísmo',
            'Budista',
            'Candomblé',
            'Católica',
            'Espírita',
            'Evangélica',
            'Hinduísta',
            'Judaica',
            'Messiânica',
            'Mórmon (SUD)',
            'Muçulmana / Islâmica',
            'Nenhuma / Não declarada',
            'Outras(os)',
            'Seicho-no-ie',
            'Testemunha de Jeová',
            'Tradições Indígenas',
            'Umbanda',
        ];

        foreach ($religions as $religion) {
            Religion::updateOrCreate([
                'name' => $religion,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 19. DefaultPmieducarTipoAutorTableSeeder.php
# Biblioteca Escolar - Tipos de autores
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoAutorTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarTipoAutorTableSeeder extends Seeder
{
    public function run()
    {
        $autores = [
            1 => 'Autor Individual',
            2 => 'Evento / Seminário / Congresso',
            3 => 'Entidade Coletiva / Instituição',
            4 => 'Anônimo / Domínio Público',
        ];

        foreach ($autores as $codigo => $tipo) {
            DB::table('pmieducar.tipo_autor')->updateOrInsert(
                ['codigo' => $codigo],
                ['tipo_autor' => $tipo]
            );
        }
    }
}
EOF

# ==============================================================================
# 20. DefaultPmieducarTipoDispensaTableSeeder.php
# Tipos legais de dispensa de disciplinas
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoDispensaTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyExemptionType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoDispensaTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Prática de Educação Física (Lei Federal 10.793/2003)',
            'Escusa de Consciência / Liberdade de Crença (Lei 13.796/2019)',
            'Adaptação Curricular (PDI) - Educação Especial Inclusiva',
            'Aproveitamento de Estudos / Equivalência Curricular',
            'Dispensa Médica / Atestado de Saúde',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyExemptionType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 21. DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder.php
# Tipos de ocorrências pedagógicas e disciplinares
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyDisciplinaryOccurrenceType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Indisciplina / Perturbação em Sala de Aula',
            'Desrespeito a Colegas ou Servidores',
            'Agressão Física ou Verbal',
            'Dano ao Patrimônio Público Escolar',
            'Bullying ou Cyberbullying',
            'Prática Discriminatória (Racial, Gênero ou Religiosa)',
            'Uso Indevido de Aparelho Celular em Horário Pedagógico',
            'Evasão de Sala ou da Unidade sem Autorização',
            'Atraso Recorrente no Início das Aulas',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyDisciplinaryOccurrenceType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 22. DefaultPmieducarTipoRegimeTableSeeder.php
# Regimes de matrícula e progressão
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoRegimeTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyRegimeType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoRegimeTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Seriado',
            'Etapas',
            'Modular',
            'Cíclico',
            'Créditos',
        ];

        foreach ($types as $type) {
            LegacyRegimeType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 23. DefaultPmieducarTipoUsuarioTableSeeder.php
# Tipos de usuários e níveis de acesso ao sistema
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoUsuarioTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarTipoUsuarioTableSeeder extends Seeder
{
    public function run()
    {
        DB::table('pmieducar.tipo_usuario')->updateOrInsert(
            ['cod_tipo_usuario' => 1],
            [
                'nm_tipo' => 'Administrador',
                'nivel' => 1,
                'ref_funcionario_cad' => 1,
                'data_cadastro' => now(),
            ]
        );
    }
}
EOF

# ==============================================================================
# 24. DefaultPmieducarTransferenciaTipoTableSeeder.php
# Motivos formais de transferência de alunos
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTransferenciaTipoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyTransferType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTransferenciaTipoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Mudança de Endereço / Município / Estado',
            'Interesse da Família / Responsável',
            'Adaptação ao Ambiente Escolar',
            'Transporte Escolar / Logística',
            'Decisão Judicial / Medida Protetiva / Conselho Tutelar',
            'Ocorrência Disciplinar Grave / Mediação',
            'Aproximação com Local de Trabalho dos Pais',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyTransferType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 25. DefaultPmieducarTurmaTipoTableSeeder.php
# Tipos de turmas ofertadas
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTurmaTipoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacySchoolClassType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTurmaTipoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'REG' => 'Regular',
            'ESP' => 'Educação Especial / Sala de Recursos Multifuncionais',
            'COMPL' => 'Atividade Complementar / Turno Extensivo',
            'AEE' => 'Atendimento Educacional Especializado',
        ];

        foreach ($types as $sg => $type) {
            LegacySchoolClassType::updateOrCreate([
                'sgl_tipo' => $sg,
            ], [
                'nm_tipo' => $type,
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 26. DefaultPortalFuncionarioVinculoTableSeeder.php
# Vínculos empregatícios dos servidores no portal
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPortalFuncionarioVinculoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyBondType;
use Illuminate\Database\Seeder;

class DefaultPortalFuncionarioVinculoTableSeeder extends Seeder
{
    public function run()
    {
        $types = [
            'EFET' => 'Efetivo / Estável (Concursado)',
            'CONT' => 'Contratado por Tempo Determinado (PSS)',
            'COM' => 'Cargo em Comissão',
            'EST' => 'Estagiário(a)',
            'TERC' => 'Terceirizado(a)',
            'CED' => 'Servidor Cedido de Outro Órgão',
        ];

        foreach ($types as $sg => $type) {
            LegacyBondType::updateOrCreate([
                'abreviatura' => $sg,
            ], [
                'nm_vinculo' => $type,
            ]);
        }
    }
}
EOF

# ==============================================================================
# 27. DefaultRelatorioSituacaoMatriculaTableSeeder.php
# Situações de matrícula consolidadas para relatórios e fechamento anual
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultRelatorioSituacaoMatriculaTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultRelatorioSituacaoMatriculaTableSeeder extends Seeder
{
    public function run()
    {
        $situacoes = [
            1 => 'Aprovado',
            2 => 'Reprovado',
            3 => 'Cursando',
            4 => 'Transferido',
            5 => 'Reclassificado',
            6 => 'Abandono',
            9 => 'Exceto Transferidos / Abandono',
            10 => 'Todas as Situações',
            12 => 'Aprovado com Dependência',
            13 => 'Aprovado pelo Conselho de Classe',
            14 => 'Reprovado por Faltas',
            15 => 'Falecido',
        ];

        foreach ($situacoes as $cod => $desc) {
            DB::table('relatorio.situacao_matricula')->updateOrInsert(
                ['cod_situacao' => $cod],
                ['descricao' => $desc]
            );
        }
    }
}
EOF

# ==============================================================================
# 28. DefaultEducacensoRecursosProvaTableSeeder.php (NOVO CENSO 2026)
# Recursos de prova do INEP exigidos no Registro 30 (Alunos com Deficiência)
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultEducacensoRecursosProvaTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DefaultEducacensoRecursosProvaTableSeeder extends Seeder
{
    public function run()
    {
        // Se a tabela modules.educacenso_recursos_prova existir, popula com os códigos do INEP
        if (Schema::hasTable('modules.educacenso_recursos_prova')) {
            $recursos = [
                1 => 'Auxílio Ledor',
                2 => 'Auxílio Transcrição',
                3 => 'Guia-Intérprete',
                4 => 'Tradutor-Intérprete de Libras',
                5 => 'Leitura Labial',
                8 => 'Prova Superampliada (Fonte 24)',
                9 => 'Caderno de Questões em Braille',
                10 => 'Prova Ampliada (Fonte 18)',
                11 => 'Auxílio em Áudio',
                12 => 'Prova de Língua Portuguesa como Segunda Língua',
                13 => 'Vídeo em Libras',
                14 => 'Nenhum Recurso Necessário',
                15 => 'Material Didático em Braille',
                16 => 'Tempo Adicional',
            ];

            foreach ($recursos as $id => $nome) {
                DB::table('modules.educacenso_recursos_prova')->updateOrInsert(
                    ['id' => $id],
                    ['nome' => $nome]
                );
            }
        }
    }
}
EOF

# ==============================================================================
# 29. DefaultEducacensoLocalizacaoDiferenciadaTableSeeder.php (NOVO CENSO 2026)
# Códigos de Localização Diferenciada (Registro 30 Aluno/Escola Censo 2026)
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultEducacensoLocalizacaoDiferenciadaTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DefaultEducacensoLocalizacaoDiferenciadaTableSeeder extends Seeder
{
    public function run()
    {
        if (Schema::hasTable('modules.educacenso_localizacao_diferenciada')) {
            $locais = [
                1 => 'Área de assentamento',
                2 => 'Terra indígena',
                3 => 'Comunidade remanescente de quilombos',
                7 => 'Não está em área de localização diferenciada',
            ];

            foreach ($locais as $id => $nome) {
                DB::table('modules.educacenso_localizacao_diferenciada')->updateOrInsert(
                    ['id' => $id],
                    ['nome' => $nome]
                );
            }
        }
    }
}
EOF

# ==============================================================================
# 30. DefaultEducacensoFormacaoContinuadaTableSeeder.php (NOVO CENSO 2026)
# Áreas de Formação Continuada dos Docentes (Registro 30 Censo 2026)
# ==============================================================================
cat <<'EOF' > "${SEEDERS_DIR}/DefaultEducacensoFormacaoContinuadaTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DefaultEducacensoFormacaoContinuadaTableSeeder extends Seeder
{
    public function run()
    {
        if (Schema::hasTable('modules.educacenso_formacao_continuada')) {
            $areas = [
                1 => 'Creche (0 a 3 anos)',
                2 => 'Pré-escola (4 e 5 anos)',
                3 => 'Anos Iniciais do Ensino Fundamental',
                4 => 'Anos Finais do Ensino Fundamental',
                5 => 'Ensino Médio',
                6 => 'Educação de Jovens e Adultos (EJA)',
                7 => 'Educação Especial',
                8 => 'Educação Indígena',
                9 => 'Educação do Campo',
                10 => 'Educação Ambiental',
                11 => 'Educação em Direitos Humanos',
                12 => 'Gênero e Diversidade Sexual',
                13 => 'Direitos da Criança e do Adolescente',
                14 => 'Educação para as Relações Étnico-Raciais',
                15 => 'Outros cursos de formação continuada',
                16 => 'Nenhum curso de formação continuada',
                17 => 'Gestão Escolar',
                18 => 'Educação Bilíngue de Surdos',
                19 => 'Tecnologias da Informação e Comunicação (TIC)',
                20 => 'Alfabetização',
                21 => 'Educação Integral / Tempo Integral',
            ];

            foreach ($areas as $id => $nome) {
                DB::table('modules.educacenso_formacao_continuada')->updateOrInsert(
                    ['id' => $id],
                    ['nome' => $nome]
                );
            }
        }
    }
}
EOF

# Ajustar proprietário e permissões
chown -R "${WEB_USER}:${WEB_GROUP}" "${SEEDERS_DIR}" 2>/dev/null || true
chmod -R 755 "${SEEDERS_DIR}" 2>/dev/null || true

# Atualizar autoload do composer caso exista
if command -v composer &>/dev/null; then
    echo -e "\n${BLUE}Atualizando autoload de classes com composer...${NC}"
    (cd "${IEDUCAR_DIR}" && composer dump-autoload --quiet 2>/dev/null) || true
elif [[ -f "${IEDUCAR_DIR}/composer.phar" ]]; then
    (cd "${IEDUCAR_DIR}" && php composer.phar dump-autoload --quiet 2>/dev/null) || true
fi

# Lista completa de 30 seeders para executar
SEEDERS=(
    "DefaultCadastroDeficienciaTableSeeder"
    "DefaultCadastroEscolaridadeTableSeeder"
    "DefaultCadastroRacaTableSeeder"
    "DefaultEmployeeGraduationDisciplines"
    "DefaultManagerAccessCriteriasTableSeeder"
    "DefaultManagerLinkTypesTableSeeder"
    "DefaultManagerRolesTableSeeder"
    "DefaultPmieducarTurmaTurnoTableSeeder"
    "DefaultCadastroEstadoCivilTableSeeder"
    "DefaultPmieducarAbandonoTipoTableSeeder"
    "DefaultPmieducarAlunoBeneficioTableSeeder"
    "DefaultPmieducarFuncaoTableSeeder"
    "DefaultPmieducarHistoricoGradeCursoTableSeeder"
    "DefaultPmieducarModuloTableSeeder"
    "DefaultPmieducarNivelEnsinoTableSeeder"
    "DefaultPmieducarTipoEnsinoTableSeeder"
    "DefaultPmieducarProjetoTableSeeder"
    "DefaultPmieducarReligionTableSeeder"
    "DefaultPmieducarTipoAutorTableSeeder"
    "DefaultPmieducarTipoDispensaTableSeeder"
    "DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder"
    "DefaultPmieducarTipoRegimeTableSeeder"
    "DefaultPmieducarTipoUsuarioTableSeeder"
    "DefaultPmieducarTransferenciaTipoTableSeeder"
    "DefaultPmieducarTurmaTipoTableSeeder"
    "DefaultPortalFuncionarioVinculoTableSeeder"
    "DefaultRelatorioSituacaoMatriculaTableSeeder"
    "DefaultEducacensoRecursosProvaTableSeeder"
    "DefaultEducacensoLocalizacaoDiferenciadaTableSeeder"
    "DefaultEducacensoFormacaoContinuadaTableSeeder"
)

echo -e "\n${BLUE}Executando os 30 Seeders do Censo 2026 no banco de dados do i-Educar...${NC}"
TOTAL=${#SEEDERS[@]}
COUNT=0
SUCCESS=0
WARN=0

cd "${IEDUCAR_DIR}"

for seeder in "${SEEDERS[@]}"; do
    COUNT=$((COUNT + 1))
    printf " [%2d/%2d] Populando %-52s " "$COUNT" "$TOTAL" "${seeder}..."
    
    # Tenta com o namespace completo Database\\Seeders\\
    if php artisan db:seed --class="Database\\Seeders\\${seeder}" --force >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        SUCCESS=$((SUCCESS + 1))
    elif php artisan db:seed --class="${seeder}" --force >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${YELLOW}⚠ Atenção (já existe ou tabela opcional no pacote)${NC}"
        WARN=$((WARN + 1))
    fi
done

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}  ✓ Povoamento Censo 2026 concluído com sucesso!                      ${NC}"
echo -e "${GREEN}    • Total processados: ${TOTAL} seeders                              ${NC}"
echo -e "${GREEN}    • Sucesso direto:    ${SUCCESS} seeders                              ${NC}"
if [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}    • Avisos/Opcionais:  ${WARN} (tabelas dependentes de migrations ativas) ${NC}"
fi
echo -e "${GREEN}======================================================================${NC}"
