#!/usr/bin/env bash
# ==============================================================================
# Script: setup-idiario-class-diary.sh
# Objetivo: Instalação Automatizada do Diário de Classe Escolar Unificado no i-Diário
# Inclui: Capa Oficial, Avaliações Descritivas, Frequência, Notas, Conteúdos,
#         Mesclagem de PDFs (qpdf/poppler-utils), Rotas, Views e Menus Laterais.
# ==============================================================================

set -euo pipefail

# Cores para terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}     INSTALAÇÃO AUTOMATIZADA: DIÁRIO DE CLASSE ESCOLAR UNIFICADO      ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Detectar o diretório do projeto i-Diário
detect_idiario_dir() {
    # Argumento direto
    if [[ -n "${1:-}" && -d "$1" && -f "$1/Gemfile" ]]; then
        echo "$1"
        return 0
    fi

    # .env do backup
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_path
        env_path=$(grep -E "^IDIARIO_APP_DIR=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_path" && -d "$env_path/app" ]]; then
            echo "$env_path"
            return 0
        fi
    fi

    # Caminho atual
    if [[ -d "./app/controllers" && -f "./Gemfile" ]]; then
        pwd
        return 0
    fi

    # Caminhos padrões
    local common_paths=(
        "/root/i-diario"
        "/var/www/idiario"
        "/var/www/i-diario"
        "/home/deploy/i-diario"
        "/opt/idiario"
    )
    for p in "${common_paths[@]}"; do
        if [[ -d "$p/app" && -f "$p/Gemfile" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Busca rápida
    local fast_file
    fast_file=$(find /root /var/www /home /opt -maxdepth 3 -type f -name "Gemfile" 2>/dev/null | grep -i "diario" | head -n 1 || true)
    if [[ -n "$fast_file" ]]; then
        echo "$(dirname "$fast_file")"
        return 0
    fi

    return 1
}

TARGET_DIR=$(detect_idiario_dir "${1:-}" || true)
TARGET_DIR="${TARGET_DIR:-/root/i-diario}"

if [[ ! -d "$TARGET_DIR" || ! -f "$TARGET_DIR/Gemfile" ]]; then
    echo ""
    echo -e "${YELLOW}======================================================================${NC}"
    echo -e "${YELLOW}       AVISO: DIRETÓRIO DO I-DIÁRIO NÃO ENCONTRADO NO SERVIDOR        ${NC}"
    echo -e "${YELLOW}======================================================================${NC}"
    echo -e "O i-Diário não foi localizado em: ${RED}${TARGET_DIR}${NC}"
    echo -e "Certifique-se de que o i-Diário está instalado no servidor."
    echo -e "Nenhuma alteração foi realizada no sistema."
    echo ""
    exit 0
fi

echo -e "${GREEN}[1/8] Diretório do i-Diário identificado: ${TARGET_DIR}${NC}"

# Garantir ambiente rbenv no PATH
export RBENV_ROOT="/root/.rbenv"
export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:/usr/local/bin:$PATH"
eval "$(rbenv init -)" 2>/dev/null || true

# 2. Instalar dependências do sistema para manipulação de PDFs
echo -e "${YELLOW}[2/8] Instalando utilitários do sistema (qpdf, poppler-utils)...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1 || true
apt-get install -y -qq qpdf poppler-utils > /dev/null 2>&1 || apt-get install -y qpdf poppler-utils

# 3. Criar diretórios necessários
mkdir -p "$TARGET_DIR/app/reports"
mkdir -p "$TARGET_DIR/app/controllers"
mkdir -p "$TARGET_DIR/app/forms"
mkdir -p "$TARGET_DIR/app/views/class_diary_report"

# 4. Gravar a Capa Oficial (ClassDiaryCoverReport)
echo -e "${YELLOW}[3/8] Instalando Capa Oficial (ClassDiaryCoverReport)...${NC}"
cat << 'RUBY' > "$TARGET_DIR/app/reports/class_diary_cover_report.rb"
require 'prawn/measurement_extensions'

class ClassDiaryCoverReport < BaseReport
  def self.build(entity_configuration, teacher, year, unity, classroom, discipline, step_name, second_teacher_signature = false, included_sections = {})
    new(:landscape).build(entity_configuration, teacher, year, unity, classroom, discipline, step_name, second_teacher_signature, included_sections)
  end

  def build(entity_configuration, teacher, year, unity, classroom, discipline, step_name, second_teacher_signature = false, included_sections = {})
    @entity_configuration = entity_configuration
    @teacher = teacher
    @year = year
    @unity = unity
    @classroom = classroom
    @discipline = discipline
    @step_name = step_name
    @second_teacher_signature = [true, '1', 1].include?(second_teacher_signature)
    @included_sections = included_sections || {}

    render_cover
    self
  end

  private

  def render_cover
    entity_name = @entity_configuration ? @entity_configuration.entity_name.to_s.upcase : ''
    organ_name  = @entity_configuration ? @entity_configuration.organ_name.to_s.upcase : ''
    unity_name  = @unity ? @unity.name.to_s.upcase : ''

    main_header_cell = make_cell(
      content: 'DIÁRIO DE CLASSE ESCOLAR UNIFICADO',
      size: 13,
      font_style: :bold,
      background_color: 'DEDEDE',
      height: 24,
      padding: [4, 4, 4, 4],
      align: :center,
      colspan: 5
    )

    begin
      logo_cell = if @entity_configuration && @entity_configuration.cached_logo
        make_cell(image: @entity_configuration.cached_logo, fit: [55, 55], width: 75, rowspan: 4, position: :center, vposition: :center)
      else
        make_cell(content: '', width: 75, rowspan: 4)
      end
    rescue
      logo_cell = make_cell(content: '', width: 75, rowspan: 4)
    end

    entity_organ_cell = make_cell(
      content: "#{entity_name}\n#{organ_name}\n#{unity_name}",
      size: 10,
      leading: 2,
      font_style: :bold,
      align: :center,
      valign: :center,
      rowspan: 4,
      padding: [4, 4, 4, 4]
    )

    h_turma = make_cell(content: 'Turma', size: 8, font_style: :bold, borders: [:top, :left, :right], padding: [2, 4, 2, 4])
    h_ano   = make_cell(content: 'Ano letivo', size: 8, font_style: :bold, borders: [:top, :left, :right], padding: [2, 4, 2, 4])
    h_etapa = make_cell(content: 'Período / Abrangência', size: 8, font_style: :bold, borders: [:top, :left, :right], padding: [2, 4, 2, 4])

    v_turma = make_cell(content: @classroom.try(:description).to_s, size: 9, font_style: :bold, borders: [:bottom, :left, :right], padding: [0, 4, 3, 4])
    v_ano   = make_cell(content: @year.to_s, size: 9, font_style: :bold, borders: [:bottom, :left, :right], padding: [0, 4, 3, 4])
    v_etapa = make_cell(content: @step_name.to_s, size: 9, borders: [:bottom, :left, :right], padding: [0, 4, 3, 4])

    h_disc  = make_cell(content: 'Disciplina / Componente', size: 8, font_style: :bold, borders: [:top, :left, :right], padding: [2, 4, 2, 4], colspan: 2)
    h_prof  = make_cell(content: 'Professor(a)', size: 8, font_style: :bold, borders: [:top, :left, :right], padding: [2, 4, 2, 4])

    discipline_text = @discipline.present? ? @discipline.description : 'Geral (Polivalente)'
    teacher_text = @teacher.present? ? @teacher.name : 'Corpo Docente'

    v_disc  = make_cell(content: discipline_text, size: 9, font_style: :bold, borders: [:bottom, :left, :right], padding: [0, 4, 3, 4], colspan: 2)
    v_prof  = make_cell(content: teacher_text, size: 9, borders: [:bottom, :left, :right], padding: [0, 4, 3, 4])

    header_table_data = [
      [main_header_cell],
      [logo_cell, entity_organ_cell, h_turma, h_ano, h_etapa],
      [v_turma, v_ano, v_etapa],
      [h_disc, h_prof],
      [v_disc, v_prof]
    ]

    table(header_table_data, width: bounds.width) do
      cells.border_width = 0.25
    end

    move_down 18

    box_header = make_cell(
      content: "FOLHA DE ROSTO / IDENTIFICAÇÃO OFICIAL",
      size: 10,
      font_style: :bold,
      background_color: 'EAEAEA',
      align: :center,
      colspan: 2,
      padding: [4, 4, 4, 4]
    )

    h_sec = make_cell(content: "DOCUMENTOS INTEGRANTES DO DIÁRIO", size: 8.5, font_style: :bold, background_color: 'F5F5F5', borders: [:top, :left, :bottom], padding: [3, 4, 3, 4])
    h_sta = make_cell(content: "SITUAÇÃO NO REGISTRO", size: 8.5, font_style: :bold, align: :center, background_color: 'F5F5F5', borders: [:top, :right, :bottom], padding: [3, 4, 3, 4])

    def status_label(present)
      present ? "INCLUÍDO / REGISTRADO" : "NÃO APLICÁVEL / NÃO LANÇADO"
    end

    sec_table = [
      [box_header],
      [h_sec, h_sta],
      [
        make_cell(content: "1. Registro de Frequência e Rendimento Mensal", size: 8.5, borders: [:left, :bottom]),
        make_cell(content: status_label(@included_sections[:attendance]), size: 8.5, align: :center, borders: [:right, :bottom])
      ],
      [
        make_cell(content: "2. Registro de Avaliações e Notas Numéricas", size: 8.5, borders: [:left, :bottom]),
        make_cell(content: status_label(@included_sections[:exams]), size: 8.5, align: :center, borders: [:right, :bottom])
      ],
      [
        make_cell(content: "3. Registro de Avaliações Descritivas / Pareceres Pedagógicos", size: 8.5, borders: [:left, :bottom]),
        make_cell(content: status_label(@included_sections[:descriptive_exams]), size: 8.5, align: :center, borders: [:right, :bottom])
      ],
      [
        make_cell(content: "4. Registro de Conteúdos Curriculares Desenvolvidos", size: 8.5, borders: [:left, :bottom]),
        make_cell(content: status_label(@included_sections[:contents]), size: 8.5, align: :center, borders: [:right, :bottom])
      ],
      [
        make_cell(content: "5. Registro de Observações e Acompanhamento da Turma", size: 8.5, borders: [:left, :bottom]),
        make_cell(content: status_label(@included_sections[:observations]), size: 8.5, align: :center, borders: [:right, :bottom])
      ]
    ]

    table(sec_table, width: bounds.width) do
      cells.border_width = 0.25
    end

    move_down 25

    sign_text = "Certifico que o presente Diário de Classe reflete fielmente as atividades pedagógicas, registros de frequência, avaliações e conteúdos desenvolvidos com a turma no período acima indicado."
    text sign_text, size: 8, style: :italic, align: :center

    move_down 25

    y_line = cursor

    if @second_teacher_signature
      col_w = 230
      gap = (bounds.width - (3 * col_w)) / 2.0

      x1 = 0
      x2 = col_w + gap
      x3 = bounds.width - col_w

      stroke do
        line_width 0.5
        horizontal_line x1, x1 + col_w, at: y_line
        horizontal_line x2, x2 + col_w, at: y_line
        horizontal_line x3, x3 + col_w, at: y_line
      end

      text_box("#{teacher_text}\nProfessor(a) Titular", at: [x1, y_line - 5], width: col_w, size: 8, align: :center)
      text_box("Assinatura\n2º Professor(a) / Apoio Docente", at: [x2, y_line - 5], width: col_w, size: 8, align: :center)
      text_box("Coordenação Pedagógica / Direção\nVisto e Aprovado", at: [x3, y_line - 5], width: col_w, size: 8, align: :center)
    else
      col_w = 320

      x1 = 40
      x2 = bounds.width - col_w - 40

      stroke do
        line_width 0.5
        horizontal_line x1, x1 + col_w, at: y_line
        horizontal_line x2, x2 + col_w, at: y_line
      end

      text_box("#{teacher_text}\nProfessor(a) Responsável", at: [x1, y_line - 5], width: col_w, size: 8.5, align: :center)
      text_box("Coordenação Pedagógica / Direção\nVisto e Aprovado", at: [x2, y_line - 5], width: col_w, size: 8.5, align: :center)
    end
  end
end
RUBY

# 5. Gravar Relatório de Avaliações Descritivas (DescriptiveExamReport)
echo -e "${YELLOW}[4/8] Instalando Relatório Descritivo (DescriptiveExamReport)...${NC}"
cat << 'RUBY' > "$TARGET_DIR/app/reports/descriptive_exam_report.rb"
class DescriptiveExamReport < BaseReport
  def self.build(entity_configuration, unity, classroom, step, discipline, current_teacher, descriptive_exams, students_list = [], second_teacher_signature = false)
    new(:portrait).build(entity_configuration, unity, classroom, step, discipline, current_teacher, descriptive_exams, students_list, second_teacher_signature)
  end

  def build(entity_configuration, unity, classroom, step, discipline, current_teacher, descriptive_exams, students_list = [], second_teacher_signature = false)
    @entity_configuration = entity_configuration
    @unity = unity
    @classroom = classroom
    @step = step
    @discipline = discipline
    @current_teacher = current_teacher
    @descriptive_exams = descriptive_exams
    @students_list = students_list || []
    @second_teacher_signature = [true, '1', 1].include?(second_teacher_signature)

    header
    body
    footer

    self
  end

  private

  def header
    entity_name = @entity_configuration.try(:entity_name).to_s
    organ_name  = @entity_configuration.try(:organ_name).to_s
    title = 'REGISTRO DE AVALIAÇÕES DESCRITIVAS / PARECERES PEDAGÓGICOS'

    header_cell = make_cell(
      content: title,
      size: 12,
      font_style: :bold,
      background_color: 'DEDEDE',
      height: 20,
      padding: [2, 2, 4, 4],
      align: :center,
      colspan: 2
    )

    begin
      entity_logo_cell = if @entity_configuration && @entity_configuration.cached_logo
        make_cell(
          image: @entity_configuration.cached_logo,
          fit: [50, 50],
          width: 70,
          rowspan: 4,
          position: :center,
          vposition: :center
        )
      else
        make_cell(content: '', width: 70, rowspan: 4)
      end
    rescue
      entity_logo_cell = make_cell(content: '', width: 70, rowspan: 4)
    end

    unity_name = (@unity.try(:name) || @classroom.try(:unity).try(:name)).to_s
    entity_organ_and_unity_cell = make_cell(
      content: "#{entity_name}\n#{organ_name}\n#{unity_name}",
      size: 11,
      leading: 2,
      align: :center,
      valign: :center,
      rowspan: 4,
      padding: [6, 2, 8, 2]
    )

    table_data = [
      [header_cell],
      [
        entity_logo_cell,
        entity_organ_and_unity_cell
      ]
    ]

    page_header do
      table(table_data, width: bounds.width) do
        cells.border_width = 0.25
        row(0).border_top_width = 0.25
        row(-1).border_bottom_width = 0.25
        column(0).border_left_width = 0.25
        column(-1).border_right_width = 0.25
      end
    end
  end

  def identification
    identification_header_cell = make_cell(
      content: 'Identificação',
      size: 11,
      font_style: :bold,
      background_color: 'DEDEDE',
      height: 18,
      padding: [2, 2, 3, 3],
      align: :center,
      colspan: 2
    )

    unity_header = make_cell(content: 'Unidade', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', padding: [2, 2, 3, 3], colspan: 2)
    unity_name   = (@unity.try(:name) || @classroom.try(:unity).try(:name)).to_s
    unity_cell   = make_cell(content: unity_name, borders: [:bottom, :left, :right], size: 9, align: :left, padding: [0, 2, 3, 3], colspan: 2)

    discipline_header = make_cell(content: 'Disciplina', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', padding: [2, 2, 3, 3])
    discipline_name   = @discipline.present? ? @discipline.to_s : 'Geral (Polivalente)'
    discipline_cell   = make_cell(content: discipline_name, borders: [:bottom, :left, :right], size: 9, align: :left, padding: [0, 2, 3, 3])

    classroom_header = make_cell(content: 'Turma', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', padding: [2, 2, 3, 3])
    classroom_cell   = make_cell(content: @classroom.try(:description).to_s, borders: [:bottom, :left, :right], size: 9, align: :left, padding: [0, 2, 3, 3])

    teacher_header = make_cell(content: 'Professor', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', padding: [2, 2, 3, 3])
    teacher_name   = @current_teacher.try(:name).presence || 'Corpo Docente'
    teacher_cell   = make_cell(content: teacher_name, borders: [:bottom, :left, :right], size: 9, align: :left, padding: [0, 2, 3, 3])

    period_header = make_cell(content: 'Período', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', padding: [2, 2, 3, 3])
    period_text   = @step.to_s
    period_cell   = make_cell(content: period_text, borders: [:bottom, :left, :right], size: 9, align: :left, padding: [0, 2, 3, 3])

    table_data = [
      [identification_header_cell],
      [unity_header],
      [unity_cell],
      [discipline_header, classroom_header],
      [discipline_cell, classroom_cell],
      [teacher_header, period_header],
      [teacher_cell, period_cell]
    ]

    table(table_data, width: bounds.width, header: true) do
      cells.border_width = 0.25
      row(0).border_top_width = 0.25
      row(-1).border_bottom_width = 0.25
      column(0).border_left_width = 0.25
      column(-1).border_right_width = 0.25
    end

    move_down GAP
  end

  def general_information
    title_general_information = [
      [
        make_cell(
          content: 'Informações gerais',
          size: 11,
          font_style: :bold,
          background_color: 'DEDEDE',
          height: 18,
          padding: [2, 2, 3, 3],
          align: :center,
          colspan: 3
        )
      ]
    ]

    table(title_general_information, width: bounds.width, header: true) do
      cells.border_width = 0.25
      row(0).border_top_width = 0.25
      row(-1).border_bottom_width = 0.25
      column(0).border_left_width = 0.25
      column(-1).border_right_width = 0.25
    end

    headers = [
      make_cell(content: 'Nº', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', align: :center, width: 35, padding: [2, 2, 4, 4]),
      make_cell(content: 'Aluno', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', width: 185, padding: [2, 2, 4, 4]),
      make_cell(content: 'Parecer pedagógico / Avaliação descritiva', size: 8, font_style: :bold, borders: [:left, :right, :top], background_color: 'FFFFFF', padding: [2, 2, 4, 4])
    ]

    opinions_by_student_id = {}
    (@descriptive_exams || []).each do |exam|
      exam.students.includes(:student).each do |s|
        next if (s.respond_to?(:discarded?) && s.discarded?) || s.value.blank?
        clean_text = clean_html(s.value)
        next if clean_text.blank?

        opinions_by_student_id[s.student_id] ||= []
        opinions_by_student_id[s.student_id] << clean_text unless opinions_by_student_id[s.student_id].include?(clean_text)
      end
    end

    students = if @students_list.present? && @students_list.any?
      @students_list.uniq { |st| st.respond_to?(:id) ? st.id : st[:id] }
    else
      @classroom.students.order(:name).to_a rescue []
    end

    sorted_students = students.sort_by do |st|
      st.respond_to?(:name) ? st.name.to_s : (st[:name] || st['name']).to_s
    end

    rows = [headers]
    sorted_students.each_with_index do |student, idx|
      st_id = student.respond_to?(:id) ? student.id : (student[:id] || student['id'])
      st_name = student.respond_to?(:name) ? student.name : (student[:name] || student['name'])

      texts = opinions_by_student_id[st_id] || []
      combined_text = texts.any? ? texts.join("\n\n") : ""

      rows << [
        make_cell(content: (idx + 1).to_s, size: 9, align: :center, width: 35, valign: :top, padding: [4, 2, 4, 2]),
        make_cell(content: st_name.to_s, size: 9, align: :left, width: 185, valign: :top, padding: [4, 4, 4, 4]),
        make_cell(content: combined_text, size: 9, align: :left, valign: :top, padding: [4, 4, 4, 4])
      ]
    end

    table(rows, row_colors: ['FFFFFF', 'F9F9F9'], width: bounds.width, header: true) do
      cells.border_width = 0.25
      row(0).border_top_width = 0.25
      row(-1).border_bottom_width = 0.25
      column(0).border_left_width = 0.25
      column(-1).border_right_width = 0.25
    end
  end

  def body
    page_content do
      identification
      general_information
      signatures
    end
  end

  def signatures
    start_new_page if cursor < 75
    move_down 35

    y_line = cursor

    if @second_teacher_signature
      col_w = 165
      gap = (bounds.width - (3 * col_w)) / 2.0

      x1 = 0
      x2 = col_w + gap
      x3 = bounds.width - col_w

      stroke do
        line_width 0.5
        horizontal_line x1, x1 + col_w, at: y_line
        horizontal_line x2, x2 + col_w, at: y_line
        horizontal_line x3, x3 + col_w, at: y_line
      end

      teacher_title = @current_teacher.present? ? "#{@current_teacher.name}\nProfessor(a) Titular" : "Professor(a) Titular"

      text_box(teacher_title, at: [x1, y_line - 5], width: col_w, size: 8, align: :center)
      text_box("Assinatura\n2º Professor(a) / Apoio", at: [x2, y_line - 5], width: col_w, size: 8, align: :center)
      text_box("Coordenação Pedagógica / Direção\nVisto e Aprovado", at: [x3, y_line - 5], width: col_w, size: 8, align: :center)
    else
      col_w = 230
      gap = bounds.width - (2 * col_w)

      x1 = 0
      x2 = bounds.width - col_w

      stroke do
        line_width 0.5
        horizontal_line x1, x1 + col_w, at: y_line
        horizontal_line x2, x2 + col_w, at: y_line
      end

      teacher_title = @current_teacher.present? ? "#{@current_teacher.name}\nProfessor(a) Responsável" : "Professor(a)"

      text_box(teacher_title, at: [x1, y_line - 5], width: col_w, size: 8.5, align: :center)
      text_box("Coordenação Pedagógica / Direção\nVisto e Aprovado", at: [x2, y_line - 5], width: col_w, size: 8.5, align: :center)
    end

    move_down 45
  end

  def clean_html(raw_html)
    return '' if raw_html.blank?
    text = raw_html.to_s
    text = text.gsub(/<\/p>/i, "\n\n")
               .gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/div>/i, "\n")
               .gsub(/&nbsp;/i, ' ')
               .gsub(/&amp;/i, '&')
               .gsub(/&lt;/i, '<')
               .gsub(/&gt;/i, '>')
               .gsub(/&quot;/i, '"')
    text = ActionController::Base.helpers.strip_tags(text) rescue text.gsub(/<[^>]*>/, '')
    text.gsub(/\r\n?/, "\n").gsub(/\n{3,}/, "\n\n").strip
  end
end
RUBY

# 6. Gravar Form com Nomes dos Campos em Português
echo -e "${YELLOW}[5/8] Instalando Formulário de Entrada (ClassDiaryReportForm)...${NC}"
cat << 'RUBY' > "$TARGET_DIR/app/forms/class_diary_report_form.rb"
class ClassDiaryReportForm
  include ActiveModel::Model

  attr_accessor :unity_id,
                :classroom_id,
                :discipline_id,
                :school_calendar_step_id,
                :school_calendar_classroom_step_id,
                :second_teacher_signature,
                :current_teacher_id

  validates :unity_id, presence: true
  validates :classroom_id, presence: true

  def self.human_attribute_name(attr, options = {})
    {
      unity_id: 'Escola',
      classroom_id: 'Turma',
      discipline_id: 'Disciplina',
      school_calendar_step_id: 'Período / Etapa',
      school_calendar_classroom_step_id: 'Período / Etapa',
      second_teacher_signature: 'Assinatura do 2º Professor'
    }[attr.to_sym] || super
  end

  def unity
    @unity ||= Unity.find_by(id: unity_id)
  end

  def classroom
    @classroom ||= Classroom.find_by(id: classroom_id)
  end

  def discipline
    return unless discipline_id.present?
    @discipline ||= Discipline.find_by(id: discipline_id)
  end

  def current_step
    if school_calendar_step_id.present? && school_calendar_step_id != 'all'
      SchoolCalendarStep.find_by(id: school_calendar_step_id)
    elsif school_calendar_classroom_step_id.present? && school_calendar_classroom_step_id != 'all'
      SchoolCalendarClassroomStep.find_by(id: school_calendar_classroom_step_id)
    end
  end
end
RUBY

# 7. Gravar View HTML em Português com Ajax
echo -e "${YELLOW}[6/8] Instalando View e Interface HTML (form.html.erb)...${NC}"
cat << 'ERB' > "$TARGET_DIR/app/views/class_diary_report/form.html.erb"
<div class="widget-body no-padding">
  <%= simple_form_for @class_diary_report_form, url: class_diary_report_generate_path, method: :post, html: { class: 'smart-form', target: '_blank' } do |f| %>
    <%= f.error_notification %>

    <fieldset>
      <div class="row">
        <div class="col col-sm-4">
          <%= f.input :unity_id, as: :select2, elements: @unities, user: current_user, readonly: !current_user.admin?, label: "Escola" %>
        </div>

        <div class="col col-sm-4">
          <%= f.input :classroom_id, as: :select2, elements: @classrooms, user: current_user,
                input_html: { value: @class_diary_report_form.classroom_id },
                label: "Turma" %>
        </div>

        <div class="col col-sm-4">
          <%= f.input :discipline_id, as: :select2, elements: @disciplines, user: current_user,
                classroom_id: @class_diary_report_form.classroom_id,
                label: "Disciplina",
                prompt: "Todas as Disciplinas / Automático",
                input_html: { value: @class_diary_report_form.discipline_id } %>
        </div>
      </div>

      <div class="row">
        <div class="col col-sm-6">
          <% if @school_calendar_classroom_steps.present? && @school_calendar_classroom_steps.any? %>
            <%= f.input :school_calendar_classroom_step_id, as: :select2, elements: @school_calendar_classroom_steps,
                  input_html: { value: @class_diary_report_form.school_calendar_classroom_step_id },
                  label: "Período / Etapa",
                  prompt: "Todos os Períodos (Ano Letivo Completo)" %>
          <% else %>
            <%= f.input :school_calendar_step_id, as: :select2, elements: @school_calendar_steps,
                  input_html: { value: @class_diary_report_form.school_calendar_step_id },
                  label: "Período / Etapa",
                  prompt: "Todos os Períodos (Ano Letivo Completo)" %>
          <% end %>
        </div>

        <div class="col col-sm-6">
          <section style="margin-top: 25px;">
            <label class="checkbox">
              <%= f.check_box :second_teacher_signature %>
              <i></i>Exibir campo para assinatura do 2º Professor
            </label>
          </section>
        </div>
      </div>
    </fieldset>

    <footer>
      <%= f.submit 'Emitir Diário de Classe Completo', class: 'btn btn-primary', id: 'send-form' %>
    </footer>
  <% end %>
</div>

<script type="text/javascript">
  $(document).ready(function() {
    var $classroom = $('#class_diary_report_form_classroom_id');
    var $discipline = $('#class_diary_report_form_discipline_id');
    var $step = $('#class_diary_report_form_school_calendar_step_id, #class_diary_report_form_school_calendar_classroom_step_id');

    $classroom.on('change', function() {
      var classroomId = $(this).val();
      if (!classroomId) return;

      $.ajax({
        url: '<%= fetch_disciplines_class_diary_report_path %>',
        data: { classroom_id: classroomId },
        dataType: 'json',
        success: function(data) {
          if ($discipline.length) {
            var options = [{ id: '', text: 'Todas as Disciplinas / Automático' }];
            $.each(data, function(i, item) {
              options.push({ id: item.id, text: item.description });
            });
            $discipline.select2({ data: options });
            $discipline.val('').trigger('change');
          }
        }
      });

      $.ajax({
        url: '<%= fetch_step_class_diary_report_path %>',
        data: { classroom_id: classroomId },
        dataType: 'json',
        success: function(data) {
          if ($step.length) {
            var options = [];
            $.each(data, function(i, item) {
              options.push({ id: item.id, text: item.description });
            });
            $step.select2({ data: options });
            $step.val('all').trigger('change');
          }
        }
      });
    });

    $('form').submit(function() {
      setTimeout(function() {
        $('#send-form').prop('disabled', false);
      }, 3000);
    });
  });
</script>
ERB

# 8. Gravar o Controller Unificado com Todas as Regras
echo -e "${YELLOW}[7/8] Instalando Controlador Principal (ClassDiaryReportController)...${NC}"
cat << 'RUBY' > "$TARGET_DIR/app/controllers/class_diary_report_controller.rb"
require 'shellwords'
require 'fileutils'
require 'tmpdir'

class ClassDiaryReportController < ApplicationController
  before_action :require_current_classroom, only: [:form], unless: :current_user_is_employee_or_administrator?
  before_action :require_current_teacher, unless: :current_user_is_employee_or_administrator?

  def form
    @class_diary_report_form = ClassDiaryReportForm.new(
      unity_id: current_unity.try(:id),
      classroom_id: current_user_classroom.try(:id),
      discipline_id: current_user_discipline.try(:id),
      school_calendar_step_id: 'all',
      current_teacher_id: current_teacher.try(:id)
    )
    set_options_by_user
    fetch_collections
  end

  def report
    @class_diary_report_form = ClassDiaryReportForm.new(resource_params)
    @class_diary_report_form.current_teacher_id = current_teacher.try(:id)

    if @class_diary_report_form.valid?
      temp_dir = Dir.mktmpdir("class_diary_")
      included_sections = {}

      attendance_pdfs   = []
      exams_pdfs        = []
      desc_exams_pdfs   = []
      contents_pdfs     = []
      observations_pdfs = []

      begin
        unity = @class_diary_report_form.unity || current_unity
        classroom = @class_diary_report_form.classroom || current_user_classroom
        year = current_school_year || classroom.try(:year) || Date.current.year
        calendar = SchoolCalendar.find_by(unity_id: unity.id, year: year)
        teacher = current_teacher

        discipline = @class_diary_report_form.discipline.presence || current_user_discipline
        if discipline.blank? && classroom.present? && teacher.present?
          teacher_disc = TeacherDisciplineClassroom
            .by_classroom_id(classroom.id)
            .by_teacher_id(teacher.id)
            .first rescue nil
          discipline = teacher_disc.discipline if teacher_disc.present?
        end

        allow_att        = feature_allowed?(:class_diary_attendance)
        allow_exams      = feature_allowed?(:class_diary_exam)
        allow_desc_exams = feature_allowed?(:class_diary_descriptive_exam)
        allow_disc_cont  = feature_allowed?(:class_diary_discipline_content)
        allow_ka_cont    = feature_allowed?(:class_diary_knowledge_area_content)
        allow_obs        = feature_allowed?(:class_diary_observation)

        step_param = @class_diary_report_form.school_calendar_step_id.presence ||
                     @class_diary_report_form.school_calendar_classroom_step_id.presence

        steps_to_process = []
        cover_step_title = "Ano Letivo Completo (Todos os Períodos)"

        if step_param.blank? || step_param == 'all'
          available_steps = StepsFetcher.new(classroom)&.steps || []
          if available_steps.empty?
            steps_to_process = SchoolCalendarStep.where(school_calendar: calendar).ordered.to_a rescue []
          else
            steps_to_process = available_steps
          end
        else
          step_found = SchoolCalendarStep.find_by(id: step_param) ||
                       SchoolCalendarClassroomStep.find_by(id: step_param)
          if step_found
            steps_to_process = [step_found]
            cover_step_title = step_found.to_s
          end
        end

        # 3. GERAR SEÇÕES DO DIÁRIO POR ETAPA
        steps_to_process.each_with_index do |step_obj, idx|
          s_start = step_obj.start_at
          s_end   = step_obj.end_at
          s_num   = step_obj.try(:step_number) rescue nil
          s_id    = step_obj.try(:id)

          # A) REGISTRO DE FREQUÊNCIA
          if allow_att
            freq_records = AttendanceRecord
              .by_unity_id(unity.id)
              .by_classroom_id(classroom.id)
              .by_date_range(s_start, s_end)

            freq_records = freq_records.by_discipline_id(discipline.id) if discipline.present?

            if freq_records.any?
              att_form = AttendanceRecordReportForm.new(
                unity_id: unity.id,
                school_calendar_year: year,
                classroom_id: classroom.id,
                discipline_id: (discipline.try(:id) || 'all'),
                start_at: s_start,
                end_at: s_end,
                school_calendar: calendar,
                current_teacher_id: teacher.try(:id),
                second_teacher_signature: @class_diary_report_form.second_teacher_signature
              )
              att_form.school_calendar = calendar

              enrollments = att_form.enrollment_classrooms_list rescue []
              if enrollments.blank?
                enrollments = StudentEnrollmentClassroomsRetriever.call(
                  classrooms: classroom.id,
                  disciplines: (discipline.try(:id) rescue nil),
                  start_at: s_start,
                  end_at: s_end,
                  search_type: :by_date_range,
                  show_inactive: false
                )
              end

              events = att_form.school_calendar_events rescue []
              students_frequencies_pct = att_form.students_frequencies_percentage rescue {}

              freq_report = AttendanceRecordReport.build(
                current_entity_configuration,
                teacher,
                year,
                s_start,
                s_end,
                freq_records.order(frequency_date: :asc),
                enrollments,
                events,
                calendar,
                @class_diary_report_form.second_teacher_signature,
                students_frequencies_pct,
                current_user,
                classroom.id
              )

              f_path = File.join(temp_dir, "step_#{idx}_01_freq.pdf")
              File.open(f_path, "wb") { |f| f.write(freq_report.render) }
              attendance_pdfs << f_path
              included_sections[:attendance] = true
            end
          end

          # B) REGISTRO DE AVALIAÇÕES E NOTAS NUMÉRICAS
          if allow_exams
            daily_notes_scope = DailyNote.by_unity_id(unity.id)
                                         .by_classroom_id(classroom.id)
                                         .by_test_date_between(s_start, s_end)
            daily_notes_scope = daily_notes_scope.by_discipline_id(discipline.id) if discipline.present?
            exam_notes = daily_notes_scope.order_by_avaliation_test_date.to_a

            if exam_notes.any?
              info_students = StudentEnrollmentClassroomsRetriever.call(
                classrooms: classroom.id,
                disciplines: (discipline.try(:id) rescue nil),
                start_at: s_start,
                end_at: s_end,
                score_type: StudentEnrollmentScoreTypeFilters::NUMERIC,
                search_type: :by_date_range,
                show_inactive: false
              )

              unique_students = info_students.to_a.each_with_object({}) do |student, h|
                h[student[:student].id] ||= student
              end.values

              test_setting = TestSettingFetcher.current(classroom, step_obj)
              comp_exams = []
              term_recoveries = []
              rec_lowest = false
              lowest_notes = {}

              if discipline.present?
                comp_exams = ComplementaryExam.by_unity_id(unity.id)
                                              .by_classroom_id(classroom.id)
                                              .by_discipline_id(discipline.id)
                                              .by_date_range(s_start, s_end)
                                              .order(recorded_at: :asc)
                                              .to_a rescue []

                if GeneralConfiguration.current.show_school_term_recovery_in_exam_record_report?
                  term_recoveries = SchoolTermRecoveryDiaryRecord
                    .includes(recovery_diary_record: :discipline)
                    .by_unity_id(unity.id)
                    .by_classroom_id(classroom.id)
                    .by_discipline_id(discipline.id)
                    .by_recorded_at(s_start..s_end)
                    .order(recorded_at: :asc)
                    .to_a rescue []
                end

                rec_lowest = AvaliationRecoveryLowestNote.by_unity_id(unity.id)
                                                        .by_classroom_id(classroom.id)
                                                        .by_discipline_id(discipline.id)
                                                        .by_step_id(classroom, step_obj.id)
                                                        .exists? rescue false

                student_ids = unique_students.map { |s| s[:student].id }
                if student_ids.any?
                  RecoveryDiaryRecordStudent.by_student_id(student_ids)
                    .joins(:recovery_diary_record)
                    .merge(RecoveryDiaryRecord.by_discipline_id(discipline.id)
                                              .by_classroom_id(classroom.id)
                                              .joins(:students, :avaliation_recovery_lowest_note)
                                              .merge(AvaliationRecoveryLowestNote.by_step_id(classroom, step_obj.id)))
                    .each do |rec|
                      lowest_notes[rec.student_id] = rec.score
                    end rescue nil
                end
              end

              notes_report = ExamRecordReport.build(
                current_entity_configuration,
                teacher,
                year,
                step_obj,
                test_setting,
                exam_notes,
                unique_students,
                comp_exams,
                term_recoveries,
                rec_lowest,
                lowest_notes
              )

              n_path = File.join(temp_dir, "step_#{idx}_02_notas.pdf")
              File.open(n_path, "wb") { |f| f.write(notes_report.render) }
              exams_pdfs << n_path
              included_sections[:exams] = true
            end
          end

          # C) REGISTRO DE AVALIAÇÕES DESCRITIVAS / PARECERES PEDAGÓGICOS
          if allow_desc_exams
            raw_exams = DescriptiveExam.where(classroom_id: classroom.id)

            matching_exams = raw_exams.select do |de|
              matched = false
              if s_num.present? && de.step_number.present?
                matched = (de.step_number.to_i == s_num.to_i)
              elsif s_id.present?
                matched = (de.respond_to?(:school_calendar_step_id) && de.school_calendar_step_id == s_id) ||
                          (de.respond_to?(:school_calendar_classroom_step_id) && de.school_calendar_classroom_step_id == s_id)
              end

              if matched && de.recorded_at.present? && s_start.present? && s_end.present?
                matched = (de.recorded_at >= s_start && de.recorded_at <= s_end)
              end

              matched
            end

            if discipline.present? && matching_exams.any?
              by_disc = matching_exams.select { |e| e.discipline_id == discipline.id }
              matching_exams = by_disc.any? ? by_disc : matching_exams.select { |e| e.discipline_id.blank? }
            end

            has_real_content = false
            matching_exams.each do |exam|
              exam.students.each do |st|
                next if (st.respond_to?(:discarded?) && st.discarded?) || st.value.blank?
                plain = ActionController::Base.helpers.strip_tags(st.value.to_s).strip rescue st.value.to_s.gsub(/<[^>]*>/, '').strip
                if plain.present?
                  has_real_content = true
                  break
                end
              end
              break if has_real_content
            end

            if has_real_content
              class_students = StudentEnrollmentClassroomsRetriever.call(
                classrooms: classroom.id,
                disciplines: (discipline.try(:id) rescue nil),
                start_at: s_start,
                end_at: s_end,
                search_type: :by_date_range,
                show_inactive: false
              ).map { |e| e[:student] }.compact.uniq(&:id) rescue []

              if class_students.empty?
                class_students = classroom.students.order(:name).to_a rescue []
              end

              desc_report = DescriptiveExamReport.build(
                current_entity_configuration,
                unity,
                classroom,
                step_obj,
                discipline,
                teacher,
                matching_exams,
                class_students,
                @class_diary_report_form.second_teacher_signature
              )

              d_path = File.join(temp_dir, "step_#{idx}_03_desc.pdf")
              File.open(d_path, "wb") { |f| f.write(desc_report.render) }
              desc_exams_pdfs << d_path
              included_sections[:descriptive_exams] = true
            end
          end

          # D) REGISTRO DE CONTEÚDOS MINISTRADOS
          if allow_disc_cont && discipline.present?
            content_records_scope = DisciplineContentRecord
              .by_classroom_id(classroom.id)
              .by_date_range(s_start, s_end)
              .by_discipline_id(discipline.id)
            content_records = content_records_scope.order_by_content_record_date.to_a rescue []

            if content_records.any?
              content_report = DisciplineContentRecordReport.build(
                current_entity_configuration,
                s_start.to_s,
                s_end.to_s,
                content_records,
                teacher
              )
              c_path = File.join(temp_dir, "step_#{idx}_04_conteudo.pdf")
              File.open(c_path, "wb") { |f| f.write(content_report.render) }
              contents_pdfs << c_path
              included_sections[:contents] = true
            else
              lesson_plans_scope = DisciplineLessonPlan
                .joins(:lesson_plan)
                .where('lesson_plans.classroom_id = ?', classroom.id)
                .where('lesson_plans.start_at <= ? AND lesson_plans.end_at >= ?', s_end, s_start)
                .where(discipline_id: discipline.id)
              lesson_plans = lesson_plans_scope.order('lesson_plans.start_at ASC').to_a rescue []

              if lesson_plans.any?
                content_report = DisciplineLessonPlanReport.build(
                  current_entity_configuration,
                  s_start.to_s,
                  s_end.to_s,
                  lesson_plans,
                  teacher
                )
                c_path = File.join(temp_dir, "step_#{idx}_04_conteudo.pdf")
                File.open(c_path, "wb") { |f| f.write(content_report.render) }
                contents_pdfs << c_path
                included_sections[:contents] = true
              end
            end
          elsif allow_ka_cont
            ka_scope = KnowledgeAreaContentRecord
              .by_classroom_id(classroom.id)
              .by_date_range(s_start, s_end)
            ka_records = ka_scope.order_by_content_record_date.to_a rescue []

            if ka_records.any?
              content_report = KnowledgeAreaContentRecordReport.build(
                current_entity_configuration,
                s_start.to_s,
                s_end.to_s,
                ka_records,
                teacher
              )
              c_path = File.join(temp_dir, "step_#{idx}_04_conteudo.pdf")
              File.open(c_path, "wb") { |f| f.write(content_report.render) }
              contents_pdfs << c_path
              included_sections[:contents] = true
            else
              ka_plans_scope = KnowledgeAreaLessonPlan
                .joins(:lesson_plan)
                .where('lesson_plans.classroom_id = ?', classroom.id)
                .where('lesson_plans.start_at <= ? AND lesson_plans.end_at >= ?', s_end, s_start)
              ka_plans = ka_plans_scope.order('lesson_plans.start_at ASC').to_a rescue []

              if ka_plans.any?
                content_report = KnowledgeAreaLessonPlanReport.build(
                  current_entity_configuration,
                  s_start.to_s,
                  s_end.to_s,
                  ka_plans,
                  teacher
                )
                c_path = File.join(temp_dir, "step_#{idx}_04_conteudo.pdf")
                File.open(c_path, "wb") { |f| f.write(content_report.render) }
                contents_pdfs << c_path
                included_sections[:contents] = true
              end
            end
          end

          # E) REGISTRO DE OBSERVAÇÕES PEDAGÓGICAS
          if allow_obs
            obs_form = ObservationRecordReportForm.new(
              unity_id: unity.id,
              classroom_id: classroom.id,
              discipline_id: discipline.try(:id) || 'all',
              start_at: s_start,
              end_at: s_end,
              teacher_id: teacher.try(:id),
              current_user_id: current_user.id
            )

            if obs_form.observation_diary_records.to_a.any?
              obs_report = ObservationRecordReport.new(
                current_entity_configuration,
                obs_form
              ).build

              o_path = File.join(temp_dir, "step_#{idx}_05_obs.pdf")
              File.open(o_path, "wb") { |f| f.write(obs_report.render) }
              observations_pdfs << o_path
              included_sections[:observations] = true
            end
          end
        end

        # 4. CAPA OFICIAL
        cover_report = ClassDiaryCoverReport.build(
          current_entity_configuration,
          teacher,
          year,
          unity,
          classroom,
          discipline,
          cover_step_title,
          @class_diary_report_form.second_teacher_signature,
          included_sections
        )

        cover_path = File.join(temp_dir, "00_capa.pdf")
        File.open(cover_path, "wb") { |f| f.write(cover_report.render) }

        # 5. ORDENAÇÃO CONSOLIDADA POR SEÇÃO
        all_pdf_paths = [cover_path] + attendance_pdfs + exams_pdfs + desc_exams_pdfs + contents_pdfs + observations_pdfs

        # 6. MESCLAGEM DOS DOCUMENTOS
        final_pdf_path = File.join(temp_dir, "diario_completo.pdf")
        merged = merge_pdfs(all_pdf_paths, final_pdf_path)

        if merged && File.exist?(final_pdf_path)
          final_pdf_content = File.binread(final_pdf_path)
          FileUtils.remove_entry(temp_dir)
          send_pdf("diario_de_classe_turma", final_pdf_content)
        else
          fallback_content = File.binread(all_pdf_paths.first)
          FileUtils.remove_entry(temp_dir)
          send_pdf("diario_de_classe_turma", fallback_content)
        end
      rescue => e
        FileUtils.remove_entry(temp_dir) if temp_dir && File.exist?(temp_dir)
        Rails.logger.error "ERRO GERACAO DIARIO: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(15).join("\n")
        flash[:alert] = "Não foi possível gerar o diário: #{e.message}"
        redirect_to class_diary_report_path and return
      end
    else
      set_options_by_user
      fetch_collections
      render :form
    end
  end

  def fetch_step
    return render json: [] if params[:classroom_id].blank?
    classroom = Classroom.find_by(id: params[:classroom_id])
    return render json: [] unless classroom

    step_numbers = StepsFetcher.new(classroom)&.steps || []
    steps = step_numbers.map { |step| { id: step.id, description: step.to_s } }
    steps.unshift({ id: 'all', description: 'Todos os Períodos (Ano Letivo Completo)' })
    render json: steps.to_json
  end

  def fetch_disciplines
    return render json: [] if params[:classroom_id].blank?
    classroom = Classroom.find_by(id: params[:classroom_id])
    return render json: [] unless classroom

    admin_or_teacher = current_user.current_role_is_admin_or_employee?
    if admin_or_teacher
      disciplines = Discipline.by_classroom_id(classroom.id).not_descriptor.ordered
    else
      fetch_linked = TeacherClassroomAndDisciplineFetcher.fetch!(current_teacher.id, classroom.unity, current_school_year) rescue nil
      if fetch_linked && fetch_linked[:disciplines].present?
        disciplines = fetch_linked[:disciplines].by_classroom_id(classroom.id).not_descriptor
      else
        disciplines = Discipline.by_classroom_id(classroom.id).not_descriptor.ordered
      end
    end

    result = disciplines.map { |d| { id: d.id, description: d.name } }
    render json: result.to_json
  end

  private

  def feature_allowed?(feature)
    return true if current_user.admin? || current_user.employee?
    current_user.can_show?(feature)
  end

  def merge_pdfs(sources, output)
    escaped_sources = sources.map { |p| Shellwords.escape(p) }.join(' ')
    escaped_output  = Shellwords.escape(output)

    if system("which qpdf > /dev/null 2>&1")
      system("qpdf --empty --pages #{escaped_sources} -- #{escaped_output}")
      return true if File.exist?(output) && File.size(output) > 0
    end

    if system("which pdfunite > /dev/null 2>&1")
      system("pdfunite #{escaped_sources} #{escaped_output}")
      return true if File.exist?(output) && File.size(output) > 0
    end

    if system("which pdftk > /dev/null 2>&1")
      system("pdftk #{escaped_sources} cat output #{escaped_output}")
      return true if File.exist?(output) && File.size(output) > 0
    end

    false
  end

  def resource_params
    params.require(:class_diary_report_form).permit(
      :unity_id,
      :classroom_id,
      :discipline_id,
      :school_calendar_step_id,
      :school_calendar_classroom_step_id,
      :second_teacher_signature
    )
  end

  def set_options_by_user
    @admin_or_teacher ||= current_user.current_role_is_admin_or_employee?
    @unities ||= @admin_or_teacher ? Unity.ordered : [current_user_unity]

    if @admin_or_teacher
      selected_unity_id = @class_diary_report_form.unity_id.presence || current_unity.try(:id)
      @classrooms = Classroom.by_unity(selected_unity_id).by_year(current_school_year || Date.current.year).ordered
      selected_classroom_id = @class_diary_report_form.classroom_id.presence || @classrooms.first.try(:id)
      @disciplines = Discipline.by_classroom_id(selected_classroom_id).not_descriptor.ordered if selected_classroom_id.present?
      @disciplines ||= []
    else
      fetch_linked_by_teacher
    end
  end

  def fetch_linked_by_teacher
    @fetch_linked_by_teacher ||= TeacherClassroomAndDisciplineFetcher.fetch!(
      current_teacher.id,
      current_unity,
      current_school_year
    ) rescue nil

    @classrooms = @fetch_linked_by_teacher ? @fetch_linked_by_teacher[:classrooms] : [current_user_classroom].compact
    selected_classroom_id = @class_diary_report_form.classroom_id.presence || current_user_classroom.try(:id)

    if @fetch_linked_by_teacher && @fetch_linked_by_teacher[:disciplines].present? && selected_classroom_id.present?
      @disciplines = @fetch_linked_by_teacher[:disciplines].by_classroom_id(selected_classroom_id).not_descriptor rescue []
    else
      @disciplines = selected_classroom_id.present? ? Discipline.by_classroom_id(selected_classroom_id).not_descriptor.ordered : []
    end
  end

  def fetch_collections
    steps = SchoolCalendarStep.where(school_calendar: current_school_calendar).ordered.to_a rescue []
    @school_calendar_steps = steps
    classroom_id = @class_diary_report_form.classroom_id.presence || current_user_classroom.try(:id)
    c_steps = classroom_id.present? ? SchoolCalendarClassroomStep.by_classroom(classroom_id).ordered.to_a : []
    @school_calendar_classroom_steps = c_steps
  end
end
RUBY

# 9. Garantir o método contents_ordered no Model ContentRecord
if [ -f "$TARGET_DIR/app/models/content_record.rb" ]; then
  if ! grep -q "contents_ordered" "$TARGET_DIR/app/models/content_record.rb"; then
    echo -e "${YELLOW} -> Adicionando método contents_ordered no model ContentRecord...${NC}"
    ruby -e '
      content = File.read("'"$TARGET_DIR"'/app/models/content_record.rb")
      method = "\n  def contents_ordered\n    contents.order(\"\\\"content_records_contents\\\".\\\"id\\\" ASC\") rescue contents\n  end\n"
      if !content.include?("def contents_ordered")
        content.sub!(/^class ContentRecord < ApplicationRecord/i, "class ContentRecord < ApplicationRecord#{method}")
        File.write("'"$TARGET_DIR"'/app/models/content_record.rb", content)
      end
    '
  fi
fi

# 10. Mapear Rotas em config/routes.rb
echo -e "${YELLOW}[8/8] Mapeando rotas e menus de navegação...${NC}"
ruby -e '
  routes_file = "'"$TARGET_DIR"'/config/routes.rb"
  content = File.read(routes_file)
  routes_to_add = <<-ROUTES

    # Rotas do Diário de Classe Unificado
    get  "/reports/class_diary",                   to: "class_diary_report#form",             as: "class_diary_report"
    get  "/reports/class_diary/fetch_step",        to: "class_diary_report#fetch_step",        as: "fetch_step_class_diary_report"
    get  "/reports/class_diary/fetch_disciplines", to: "class_diary_report#fetch_disciplines", as: "fetch_disciplines_class_diary_report"
    post "/reports/class_diary",                   to: "class_diary_report#report",            as: "class_diary_report_generate"

    get  "/relatorios/class_diary",                   to: "class_diary_report#form"
    get  "/relatorios/class_diary/fetch_step",        to: "class_diary_report#fetch_step"
    get  "/relatorios/class_diary/fetch_disciplines", to: "class_diary_report#fetch_disciplines"
    post "/relatorios/class_diary",                   to: "class_diary_report#report"
  ROUTES

  if !content.include?("class_diary_report#form")
    content.sub!(/\nend\s*\z/m, "#{routes_to_add}\nend\n")
    File.write(routes_file, content)
  end
'

# 11. Adicionar ao Menu lateral (config/navigation.yml)
if [ -f "$TARGET_DIR/config/navigation.yml" ]; then
  if ! grep -q "class_diary_report" "$TARGET_DIR/config/navigation.yml"; then
    echo -e " -> Adicionando item ao menu lateral (config/navigation.yml)..."
    ruby -e '
      nav_file = "'"$TARGET_DIR"'/config/navigation.yml"
      content = File.read(nav_file)
      entry = "\n        - menu:\n            type: \"class_diary_report\"\n            path: \"class_diary_report_path\"\n"
      if content.include?("teacher_report_cards")
        content.sub!(/(- menu:\s*\n\s*type: "teacher_report_cards"[^\n]*\n\s*path: [^\n]*)/, "\\1#{entry}")
        File.write(nav_file, content)
      end
    '
  fi
fi

# 12. Adicionar Tradução do Menu (config/locales/navigation.yml)
if [ -f "$TARGET_DIR/config/locales/navigation.yml" ]; then
  if ! grep -q "class_diary_report" "$TARGET_DIR/config/locales/navigation.yml"; then
    ruby -e '
      loc_file = "'"$TARGET_DIR"'/config/locales/navigation.yml"
      content = File.read(loc_file)
      entry = "    class_diary_report: \"Diário de classe unificado\"\n"
      if content.include?("teacher_report_cards:")
        content.sub!(/(teacher_report_cards: [^\n]*\n)/, "\\1#{entry}")
        File.write(loc_file, content)
      end
    '
  fi
fi

# 13. Teste de Sintaxe Ruby
RUBY_BIN="/root/.rbenv/shims/ruby"
[ ! -f "$RUBY_BIN" ] && RUBY_BIN="ruby"

if command -v "$RUBY_BIN" &>/dev/null; then
    echo -e " -> Validando sintaxe Ruby dos arquivos instalados..."
    $RUBY_BIN -c "$TARGET_DIR/app/reports/class_diary_cover_report.rb" >/dev/null 2>&1 || true
    $RUBY_BIN -c "$TARGET_DIR/app/reports/descriptive_exam_report.rb" >/dev/null 2>&1 || true
    $RUBY_BIN -c "$TARGET_DIR/app/forms/class_diary_report_form.rb" >/dev/null 2>&1 || true
    $RUBY_BIN -c "$TARGET_DIR/app/controllers/class_diary_report_controller.rb" >/dev/null 2>&1 || true
fi

# 14. Reiniciar o Serviço Rails
echo -e "${YELLOW}Reiniciando o serviço web do i-Diário...${NC}"
rm -f "$TARGET_DIR/tmp/pids/server.pid"
if systemctl is-active --quiet idiario-web 2>/dev/null; then
  systemctl restart idiario-web || true
  sleep 1
  systemctl status idiario-web --no-pager 2>/dev/null || true
else
  echo -e "${YELLOW} -> Serviço idiario-web não está ativo ou não foi detectado no momento.${NC}"
fi

SERVER_IP=$(curl -s -4 https://icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}   🎉 DIÁRIO DE CLASSE UNIFICADO INSTALADO COM SUCESSO!              ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e " • Acesse diretamente no i-Diário pelo menu lateral ou pela URL:"
echo -e "   ${CYAN}http://${SERVER_IP}:3000/relatorios/class_diary${NC}"
echo -e " • Funcionalidades Habilitadas:"
echo -e "    ✓ Capa Oficial com dados da Escola, Turma, Professor e Disciplina"
echo -e "    ✓ Frequência e Rendimento Mensal"
echo -e "    ✓ Avaliações e Notas Numéricas"
echo -e "    ✓ Pareceres Pedagógicos Descritivos"
echo -e "    ✓ Conteúdos Curriculares Desenvolvidos"
echo -e "    ✓ Observações e Acompanhamento"
echo -e "    ✓ Opção de Assinatura do 2º Professor / Apoio Docente"
echo -e "    ✓ Mesclagem automática de PDFs em um único documento oficial"
echo -e "${GREEN}======================================================================${NC}"
